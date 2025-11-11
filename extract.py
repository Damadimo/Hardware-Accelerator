# save as: extract_conv1_to_mif.py
import torch, numpy as np
import re

CKPT = "mnist_cnn.pth"     # <-- put your file name here
MIF  = "weights.mif"

def load_state_dict_any(path):
    obj = torch.load(path, map_location="cpu")
    # Some files are already a state_dict; others are {'state_dict': ...}
    if isinstance(obj, dict):
        if "state_dict" in obj and isinstance(obj["state_dict"], dict):
            return obj["state_dict"]
        # Lightning often wraps params with 'model.' prefix
        if any(k.startswith("state_dict.") for k in obj.keys()):
            return {k.split("state_dict.",1)[1]: v for k,v in obj.items()}
        # Plain state_dict?
        if any(isinstance(v, torch.Tensor) for v in obj.values()):
            return obj
    raise RuntimeError("Couldn't find a state_dict in this file.")

def pick_conv1_key(sd):
    # Common names for first conv:
    candidates = [
        "conv1.weight", "features.0.weight", "model.conv1.weight",
        "net.conv1.weight", "cnn.0.weight"
    ]
    for k in candidates:
        if k in sd:
            return k
    # Fallback: pick the first conv weight with in_ch=1
    # and kernel size between 3..7 (typical MNIST)
    best = None
    for k, v in sd.items():
        if not isinstance(v, torch.Tensor): 
            continue
        if v.ndim == 4:  # [out,in,kh,kw]
            outc, inc, kh, kw = v.shape
            if inc == 1 and 3 <= kh <= 7 and 3 <= kw <= 7:
                best = k
                break
    if best is None:
        raise RuntimeError("Could not find a conv1 weight in the checkpoint.")
    return best

def center_to_5x5(w4):
    # w4: [out, in, kh, kw]
    outc, inc, kh, kw = w4.shape
    # Crop or pad to 5x5
    if kh > 5 or kw > 5:
        cy = (kh - 5)//2
        cx = (kw - 5)//2
        w4 = w4[:, :, cy:cy+5, cx:cx+5]
    elif kh < 5 or kw < 5:
        pad_y = (5 - kh)
        pad_x = (5 - kw)
        py0 = pad_y // 2
        px0 = pad_x // 2
        py1 = pad_y - py0
        px1 = pad_x - px0
        w4 = torch.nn.functional.pad(w4, (px0, px1, py0, py1))
    return w4

def to_q1p7(x):
    scale = 2**7
    xq = torch.clamp(torch.round(x * scale), -128, 127).to(torch.int8)
    return xq

def write_mif_8x5x5(weights_q, path):
    # weights_q: [8,1,5,5] int8
    with open(path, "w") as f:
        f.write("DEPTH = 512;\nWIDTH = 8;\nADDRESS_RADIX = DEC;\nDATA_RADIX = HEX;\nCONTENT BEGIN\n")
        addr = 0
        for filt in range(8):
            for ky in range(5):
                for kx in range(5):
                    byte = int(weights_q[filt, 0, ky, kx].item()) & 0xFF
                    f.write(f"  {addr:3d} : {byte:02X};\n")
                    addr += 1
        f.write(f"  [{addr}..511] : 00;\nEND;\n")
    print(f"✅ Wrote {path}")

if __name__ == "__main__":
    sd = load_state_dict_any(CKPT)
    k = pick_conv1_key(sd)
    w = sd[k].float()                 # e.g., [10,1,5,5] or [16,1,3,3], etc.
    # Force shape to [>=8, 1, 5, 5]
    if w.shape[1] != 1:
        raise RuntimeError(f"conv1 in_channels={w.shape[1]} != 1; need grayscale.")
    w = center_to_5x5(w)              # crop/pad kernel to 5x5 if needed
    if w.shape[0] < 8:
        raise RuntimeError(f"conv1 out_channels={w.shape[0]} < 8; need at least 8.")
    w8 = w[:8, :, :5, :5]             # take first 8 filters
    w8_q = to_q1p7(w8)
    write_mif_8x5x5(w8_q, MIF)
