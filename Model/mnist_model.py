# train_and_export_mem.py
#
# Trains a small CNN on MNIST, extracts:
#   - last feature vector (length 400)
#   - FC weights (10x400) and biases (10)
# Quantizes them and writes:
#   - features.mem
#   - fc_w_flat.mem
#   - fc_b.mem
#
# These files match the expectations of fc_core.v

import os
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms
from torch.utils.data import DataLoader


###########################################
# 1. MODEL DEFINITION
###########################################

class SimpleCNN(nn.Module):
    """
    Input: 1x28x28
    conv1: 8 filters, 3x3 -> 8x26x26
    pool1: 2x2 -> 8x13x13
    conv2: 16 filters, 3x3 -> 16x11x11
    pool2: 2x2 -> 16x5x5
    flatten: 400
    fc: 400 -> 10
    """

    def __init__(self):
        super(SimpleCNN, self).__init__()
        self.conv1 = nn.Conv2d(1, 8, kernel_size=3, stride=1, padding=0)
        self.pool = nn.MaxPool2d(2, 2)
        self.conv2 = nn.Conv2d(8, 16, kernel_size=3, stride=1, padding=0)
        self.fc = nn.Linear(16 * 5 * 5, 10)

    def forward(self, x, return_features=False):
        # x: (N,1,28,28)
        x = self.conv1(x)          # (N,8,26,26)
        x = torch.relu(x)
        x = self.pool(x)           # (N,8,13,13)
        x = self.conv2(x)          # (N,16,11,11)
        x = torch.relu(x)
        x = self.pool(x)           # (N,16,5,5)
        # at this point x is the feature map we want
        feat = x.view(x.size(0), -1)   # (N, 400)
        logits = self.fc(feat)         # (N,10)
        if return_features:
            return logits, feat
        else:
            return logits


###########################################
# 2. DATA LOADING
###########################################

def get_mnist_loaders(batch_size=64):
    transform = transforms.Compose([
        transforms.ToTensor(),  # converts to [0,1] float32
    ])

    train_dataset = datasets.MNIST(
        root="./data",
        train=True,
        download=False,
        transform=transform,
    )

    test_dataset = datasets.MNIST(
        root="./data",
        train=False,
        download=True,
        transform=transform,
    )

    train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
    test_loader  = DataLoader(test_dataset, batch_size=batch_size, shuffle=False)

    return train_loader, test_loader


###########################################
# 3. TRAINING LOOP (brief, just to get a working model)
###########################################

def train_model(model, train_loader, device, epochs=2, lr=1e-3):
    model.to(device)
    model.train()

    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=lr)

    for epoch in range(epochs):
        running_loss = 0.0
        total = 0
        correct = 0

        for images, labels in train_loader:
            images = images.to(device)
            labels = labels.to(device)

            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()

            running_loss += loss.item() * images.size(0)

            _, predicted = torch.max(outputs, 1)
            total += labels.size(0)
            correct += (predicted == labels).sum().item()

        epoch_loss = running_loss / total
        epoch_acc  = correct / total * 100.0
        print(f"Epoch {epoch+1}/{epochs} - loss: {epoch_loss:.4f} - acc: {epoch_acc:.2f}%")

    return model


###########################################
# 4. EVALUATE ON ONE SAMPLE TO GET FEATURES + FC
###########################################

def get_sample_and_fc_params(model, test_loader, device):
    model.to(device)
    model.eval()

    # Get first batch
    images, labels = next(iter(test_loader))
    images = images.to(device)
    labels = labels.to(device)

    with torch.no_grad():
        logits, feats = model(images, return_features=True)  # feats shape: (N,400)

    # Pick the first sample in batch
    feat   = feats[0].cpu().numpy()          # shape (400,)
    logits0 = logits[0].cpu().numpy()        # shape (10,)
    label0  = int(labels[0].cpu().numpy())

    # FC layer parameters
    fc = model.fc
    W_fc = fc.weight.detach().cpu().numpy()  # shape (10,400)
    b_fc = fc.bias.detach().cpu().numpy()    # shape (10,)

    print("Sample true label:", label0)
    print("Model float32 logits:", logits0)
    print("Model float32 predicted digit:", int(np.argmax(logits0)))

    return feat, W_fc, b_fc, label0


###########################################
# 5. QUANTIZATION HELPERS
###########################################

def quantize_to_int8(x):
    x = np.asarray(x, dtype=np.float64)
    max_abs = np.max(np.abs(x))
    if max_abs == 0.0:
        scale = 1.0
    else:
        scale = 127.0 / max_abs
    x_scaled = x * scale
    x_q = np.clip(np.round(x_scaled), -128, 127).astype(np.int8)
    return x_q, scale

def quantize_bias_to_int16(b, feat_scale, w_scale):
    """
    Rough scaling: feat ~ feat_scale * feat_float, w ~ w_scale * w_float.
    Then feat*w ~ feat_scale*w_scale*(feat_float*w_float).
    We scale biases by the same combined factor, possibly with extra clamp.
    """
    b = np.asarray(b, dtype=np.float64)
    base_scale = feat_scale * w_scale

    max_abs = np.max(np.abs(b * base_scale))
    if max_abs == 0.0:
        bias_scale = base_scale
    else:
        max_allowed = 32767.0
        scale_factor = min(1.0, max_allowed / max_abs)
        bias_scale = base_scale * scale_factor

    b_scaled = b * bias_scale
    b_q = np.clip(np.round(b_scaled), -32768, 32767).astype(np.int16)
    return b_q, bias_scale


###########################################
# 6. WRITE .mem FILES
###########################################

def write_features_mem(feats_q, path="features.mem"):
    assert feats_q.shape == (400,)
    with open(path, "w") as f:
        for v in feats_q:
            f.write(f"{(int(v) & 0xFF):02X}\n")  # 2-digit hex

def write_fc_w_flat_mem(W_q, path="fc_w_flat.mem"):
    assert W_q.shape == (10, 400)
    W_flat = W_q.reshape(-1)  # length 4000
    with open(path, "w") as f:
        for v in W_flat:
            f.write(f"{(int(v) & 0xFF):02X}\n")

def write_fc_b_mem(b_q, path="fc_b.mem"):
    assert b_q.shape == (10,)
    with open(path, "w") as f:
        for v in b_q:
            f.write(f"{(int(v) & 0xFFFF):04X}\n")  # 4-digit hex


###########################################
# 7. INTEGER FC FORWARD (MUST MATCH VERILOG)
###########################################

def fc_int_forward(feats_q, W_q, b_q):
    """
    feats_q: (400,) int8
    W_q: (10,400) int8
    b_q: (10,) int16
    Returns:
      scores: (10,) int32
      pred_digit: int
    """
    feats_q = feats_q.astype(np.int32)
    W_q = W_q.astype(np.int32)
    b_q = b_q.astype(np.int32)

    scores = np.zeros(10, dtype=np.int32)
    for j in range(10):
        acc = int(b_q[j])
        for i in range(400):
            acc += int(feats_q[i]) * int(W_q[j, i])
        scores[j] = acc

    pred = int(np.argmax(scores))
    return scores, pred


###########################################
# 8. MAIN
###########################################

def main():
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print("Using device:", device)

    # 1) Load data
    train_loader, test_loader = get_mnist_loaders(batch_size=64)

    # 2) Create and train model (few epochs is enough for demo)
    model = SimpleCNN()
    print("Training model...")
    model = train_model(model, train_loader, device, epochs=2, lr=1e-3)

    # 3) Get one sample's features + FC params
    feat, W_fc, b_fc, label0 = get_sample_and_fc_params(model, test_loader, device)

    print("Feature vector shape:", feat.shape)
    print("FC weight shape:", W_fc.shape)
    print("FC bias shape:", b_fc.shape)

    # 4) Quantize
    feats_q, feat_scale = quantize_to_int8(feat)
    W_q, w_scale        = quantize_to_int8(W_fc)
    b_q, b_scale        = quantize_bias_to_int16(b_fc, feat_scale, w_scale)

    print("Feature scale:", feat_scale)
    print("Weight scale:", w_scale)
    print("Bias scale:  ", b_scale)

    # 5) Integer FC simulation
    scores_int, pred_digit_int = fc_int_forward(feats_q, W_q, b_q)
    print("Integer scores:", scores_int)
    print("Predicted digit (int FC):", pred_digit_int)
    print("True label:", label0)

    # 6) Write mem files
    write_features_mem(feats_q, "features.mem")
    write_fc_w_flat_mem(W_q,   "fc_w_flat.mem")
    write_fc_b_mem(b_q,        "fc_b.mem")

    print("\nWrote files: features.mem, fc_w_flat.mem, fc_b.mem")
    print("These correspond to the integer FC that predicts:", pred_digit_int)


if __name__ == "__main__":
    main()
