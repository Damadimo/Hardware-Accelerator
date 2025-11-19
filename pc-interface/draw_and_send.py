#!/usr/bin/env python3
"""
Drawing GUI + Serial Sender for FPGA Digit Classification
Creates a 28x28 canvas for drawing digits and sends them via serial to FPGA
"""

import tkinter as tk
from tkinter import messagebox, ttk
import numpy as np
import serial
import serial.tools.list_ports
import os
from datetime import datetime


class DrawingApp:
    def __init__(self, root):
        self.root = root
        self.root.title("FPGA Digit Classifier - Drawing Interface")
        
        # Canvas parameters
        self.cell_size = 16  # Each cell is 16x16 pixels
        self.grid_size = 28  # 28x28 grid
        self.canvas_size = self.cell_size * self.grid_size  # 448x448
        
        # Image data: 28x28 numpy array, uint8
        self.img = np.zeros((self.grid_size, self.grid_size), dtype=np.uint8)
        
        # Serial connection
        self.ser = None
        self.serial_port = None
        
        # Drawing state
        self.is_drawing = False
        
        self.setup_ui()
        
    def setup_ui(self):
        """Set up the user interface"""
        # Configure root window
        self.root.configure(bg='#1e1e1e')
        
        # Main frame
        main_frame = tk.Frame(self.root, padx=20, pady=20, bg='#1e1e1e')
        main_frame.pack()
        
        # Title label
        title_label = tk.Label(
            main_frame,
            text="Draw a Digit",
            font=('Helvetica', 18, 'bold'),
            bg='#1e1e1e',
            fg='#ffffff'
        )
        title_label.grid(row=0, column=0, columnspan=3, pady=(0, 15))
        
        # Canvas frame with border
        canvas_frame = tk.Frame(main_frame, bg='#3a3a3a', padx=3, pady=3)
        canvas_frame.grid(row=1, column=0, columnspan=3, pady=(0, 20))
        
        # Canvas for drawing
        self.canvas = tk.Canvas(
            canvas_frame,
            width=self.canvas_size,
            height=self.canvas_size,
            bg='#000000',
            cursor='cross',
            highlightthickness=0
        )
        self.canvas.pack()
        
        # Mouse event bindings
        self.canvas.bind('<Button-1>', self.start_drawing)
        self.canvas.bind('<B1-Motion>', self.draw)
        self.canvas.bind('<ButtonRelease-1>', self.stop_drawing)
        
        # Result label (moved above buttons for better visibility)
        self.result_label = tk.Label(
            main_frame,
            text="Draw a digit and click Classify",
            font=('Helvetica', 16, 'bold'),
            bg='#1e1e1e',
            fg='#4dabf7',
            pady=10
        )
        self.result_label.grid(row=2, column=0, columnspan=3, pady=(0, 15))
        
        # Control buttons frame
        control_frame = tk.Frame(main_frame, bg='#1e1e1e')
        control_frame.grid(row=3, column=0, columnspan=3, pady=(0, 20))
        
        # Clear button
        clear_btn = tk.Button(
            control_frame,
            text="Clear Canvas",
            command=self.clear_canvas,
            width=18,
            height=2,
            bg='#e74c3c',
            fg='#ffffff',
            font=('Helvetica', 13, 'bold'),
            relief=tk.SOLID,
            bd=1,
            cursor='hand2',
            activebackground='#c0392b',
            activeforeground='#ffffff',
            highlightthickness=0
        )
        clear_btn.grid(row=0, column=0, padx=10)
        
        # Classify button
        classify_btn = tk.Button(
            control_frame,
            text="Classify",
            command=self.classify,
            width=18,
            height=2,
            bg='#27ae60',
            fg='#ffffff',
            font=('Helvetica', 13, 'bold'),
            relief=tk.SOLID,
            bd=1,
            cursor='hand2',
            activebackground='#229954',
            activeforeground='#ffffff',
            highlightthickness=0
        )
        classify_btn.grid(row=0, column=1, padx=10)
        
        # Serial setup frame
        serial_frame = tk.LabelFrame(
            main_frame,
            text=" Serial Configuration ",
            padx=15,
            pady=15,
            bg='#2d2d2d',
            fg='#ffffff',
            font=('Helvetica', 11, 'bold'),
            relief=tk.GROOVE,
            borderwidth=2
        )
        serial_frame.grid(row=4, column=0, columnspan=3, pady=(0, 15), sticky='ew')
        
        # Port selection
        port_label = tk.Label(
            serial_frame,
            text="Port:",
            bg='#2d2d2d',
            fg='#ffffff',
            font=('Helvetica', 10)
        )
        port_label.grid(row=0, column=0, sticky='w', padx=(0, 10))
        
        self.port_var = tk.StringVar()
        self.port_combo = ttk.Combobox(
            serial_frame,
            textvariable=self.port_var,
            width=25,
            state='readonly',
            font=('Helvetica', 10)
        )
        self.port_combo.grid(row=0, column=1, padx=5)
        
        # Refresh ports button
        refresh_btn = tk.Button(
            serial_frame,
            text="Refresh",
            command=self.refresh_ports,
            width=12,
            bg='#3498db',
            fg='#ffffff',
            font=('Helvetica', 10, 'bold'),
            relief=tk.SOLID,
            bd=1,
            cursor='hand2',
            activebackground='#2980b9',
            activeforeground='#ffffff',
            highlightthickness=0
        )
        refresh_btn.grid(row=0, column=2, padx=5)
        
        # Baud rate selection
        baud_label = tk.Label(
            serial_frame,
            text="Baud Rate:",
            bg='#2d2d2d',
            fg='#ffffff',
            font=('Helvetica', 10)
        )
        baud_label.grid(row=1, column=0, sticky='w', pady=(10, 0), padx=(0, 10))
        
        self.baud_var = tk.StringVar(value="115200")
        baud_combo = ttk.Combobox(
            serial_frame,
            textvariable=self.baud_var,
            width=25,
            values=["9600", "115200", "230400", "460800"],
            state='readonly',
            font=('Helvetica', 10)
        )
        baud_combo.grid(row=1, column=1, padx=5, pady=(10, 0))
        
        # Connect/Disconnect button
        self.connect_btn = tk.Button(
            serial_frame,
            text="Connect",
            command=self.toggle_connection,
            width=12,
            bg='#16a085',
            fg='#ffffff',
            font=('Helvetica', 10, 'bold'),
            relief=tk.SOLID,
            bd=1,
            cursor='hand2',
            activebackground='#138d75',
            activeforeground='#ffffff',
            highlightthickness=0
        )
        self.connect_btn.grid(row=1, column=2, padx=5, pady=(10, 0))
        
        # Status label
        self.status_label = tk.Label(
            main_frame,
            text="Status: Not connected",
            font=('Helvetica', 10),
            bg='#1e1e1e',
            fg='#e74c3c'
        )
        self.status_label.grid(row=5, column=0, columnspan=3, pady=(0, 10))
        
        # Populate ports
        self.refresh_ports()
        
    def refresh_ports(self):
        """Refresh the list of available serial ports"""
        ports = serial.tools.list_ports.comports()
        port_list = [port.device for port in ports]
        
        if not port_list:
            port_list = ["No ports found"]
            
        self.port_combo['values'] = port_list
        if port_list and port_list[0] != "No ports found":
            self.port_combo.current(0)
    
    def toggle_connection(self):
        """Connect or disconnect from serial port"""
        if self.ser and self.ser.is_open:
            # Disconnect
            self.ser.close()
            self.ser = None
            self.connect_btn.config(text="Connect", bg='#16a085')
            self.status_label.config(text="Status: Not connected", fg='#e74c3c')
        else:
            # Connect
            port = self.port_var.get()
            if not port or port == "No ports found":
                messagebox.showerror("Error", "Please select a valid serial port")
                return
            
            try:
                baud = int(self.baud_var.get())
                self.ser = serial.Serial(port, baud, timeout=1)
                self.connect_btn.config(text="Disconnect", bg='#e74c3c')
                self.status_label.config(
                    text=f"Status: Connected to {port} at {baud} baud",
                    fg='#27ae60'
                )
            except Exception as e:
                messagebox.showerror("Connection Error", f"Failed to open port:\n{str(e)}")
                self.ser = None
    
    def start_drawing(self, event):
        """Start drawing when mouse button is pressed"""
        self.is_drawing = True
        self.draw(event)
    
    def stop_drawing(self, event):
        """Stop drawing when mouse button is released"""
        self.is_drawing = False
    
    def draw(self, event):
        """Draw on the canvas when mouse is dragged"""
        if not self.is_drawing:
            return
        
        # Convert screen coordinates to grid indices
        col = event.x // self.cell_size
        row = event.y // self.cell_size
        
        # Clamp to valid range
        col = max(0, min(col, self.grid_size - 1))
        row = max(0, min(row, self.grid_size - 1))
        
        # Draw with thicker stroke (3x3 neighborhood)
        for dr in [-1, 0, 1]:
            for dc in [-1, 0, 1]:
                r = row + dr
                c = col + dc
                
                # Check bounds
                if 0 <= r < self.grid_size and 0 <= c < self.grid_size:
                    # Set pixel to white (255)
                    self.img[r, c] = 255
                    
                    # Update canvas
                    self.draw_cell(r, c)
    
    def draw_cell(self, row, col):
        """Draw a single cell on the canvas"""
        x1 = col * self.cell_size
        y1 = row * self.cell_size
        x2 = x1 + self.cell_size
        y2 = y1 + self.cell_size
        
        # Get grayscale value
        value = self.img[row, col]
        
        # Convert to hex color
        color = f'#{value:02x}{value:02x}{value:02x}'
        
        # Draw rectangle
        self.canvas.create_rectangle(x1, y1, x2, y2, fill=color, outline='')
    
    def clear_canvas(self):
        """Clear the canvas and reset image data"""
        # Reset image array
        self.img[:, :] = 0
        
        # Clear canvas
        self.canvas.delete('all')
        self.canvas.config(bg='black')
        
        # Reset result label
        self.result_label.config(
            text="Draw a digit and click Classify",
            fg='#4dabf7'
        )
    
    def generate_mif_file(self, filename="image.mif"):
        """Generate MIF file from current image data"""
        try:
            # Flatten the image data
            flat_data = self.img.flatten()
            
            # Get the directory of the script
            script_dir = os.path.dirname(os.path.abspath(__file__))
            filepath = os.path.join(script_dir, filename)
            
            with open(filepath, 'w') as f:
                # Write MIF header
                f.write("-- Memory Initialization File for Pixel Data\n")
                f.write(f"-- Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
                f.write(f"-- Size: {len(flat_data)} pixels (28x28)\n")
                f.write("\n")
                f.write("DEPTH = 784;         -- Number of memory locations (28x28)\n")
                f.write("WIDTH = 8;           -- 8-bit grayscale values\n")
                f.write("ADDRESS_RADIX = DEC; -- Address in decimal\n")
                f.write("DATA_RADIX = HEX;    -- Data in hexadecimal\n")
                f.write("\n")
                f.write("CONTENT\n")
                f.write("BEGIN\n")
                f.write("\n")
                
                # Write pixel data
                for i, pixel in enumerate(flat_data):
                    f.write(f"  {i:3d} : {pixel:02X};\n")
                
                f.write("\n")
                f.write("END;\n")
            
            print(f"MIF file generated: {filepath}")
            return filepath
            
        except Exception as e:
            print(f"Error generating MIF file: {str(e)}")
            return None
    
    def classify(self):
        """Send image data to FPGA for classification and generate MIF file"""
        # Check if canvas is empty
        if np.sum(self.img) == 0:
            messagebox.showwarning(
                "Empty Canvas",
                "Please draw a digit first"
            )
            return
        
        # Generate MIF file
        mif_file = self.generate_mif_file("image.mif")
        if mif_file:
            print(f"✓ MIF file generated: {mif_file}")
        
        # Check if serial port is open for sending
        if not self.ser or not self.ser.is_open:
            self.result_label.config(text="MIF file generated successfully", fg='#27ae60')
            messagebox.showinfo(
                "MIF File Generated",
                f"MIF file saved to:\n{mif_file}\n\nNote: Not connected to serial port.\nConnect to send data to FPGA."
            )
            return
        
        try:
            # Flatten image to bytes (784 bytes)
            payload = self.img.flatten().astype('uint8').tobytes()
            
            # Send packet
            # Start byte: 0xAA
            self.ser.write(bytes([0xAA]))
            
            # Image data: 784 bytes
            self.ser.write(payload)
            
            # End byte: 0x55
            self.ser.write(bytes([0x55]))
            
            # Update status
            self.result_label.config(text="Sending to FPGA...", fg='#f39c12')
            self.root.update()
            
            # Read response (1 byte)
            resp = self.ser.read(1)
            
            if resp:
                predicted_digit = resp[0]
                print(f"FPGA predicted: {predicted_digit}")
                self.result_label.config(
                    text=f"Prediction: {predicted_digit}",
                    fg='#27ae60'
                )
                messagebox.showinfo(
                    "Classification Complete",
                    f"FPGA Prediction: {predicted_digit}\nMIF file: {mif_file}"
                )
            else:
                self.result_label.config(
                    text="No response from FPGA (timeout)",
                    fg='#e67e22'
                )
                messagebox.showwarning(
                    "Timeout",
                    f"No response from FPGA\nMIF file saved: {mif_file}"
                )
                
        except Exception as e:
            messagebox.showerror("Communication Error", f"Error during classification:\n{str(e)}\n\nMIF file saved: {mif_file}")
            self.result_label.config(text="Classification error", fg='#e74c3c')
    
    def on_closing(self):
        """Clean up when closing the application"""
        if self.ser and self.ser.is_open:
            self.ser.close()
        self.root.destroy()


def main():
    root = tk.Tk()
    app = DrawingApp(root)
    root.protocol("WM_DELETE_WINDOW", app.on_closing)
    root.mainloop()


if __name__ == "__main__":
    main()

