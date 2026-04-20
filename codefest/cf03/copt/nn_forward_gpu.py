import torch
import sys

# Step 1: Detect GPU
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
if device.type != "cuda":
    print("No CUDA GPU found. Exiting.")
    sys.exit(1)
print(f"Using device: {torch.cuda.get_device_name(0)}")

# Step 2: Define network 4 -> 5 ReLU -> 1 linear
model = torch.nn.Sequential(
    torch.nn.Linear(4, 5),
    torch.nn.ReLU(),
    torch.nn.Linear(5, 1)
)
model.to(device)
print(f"Model moved to: {device}")

# Step 3: Random input [16, 4], forward pass
x = torch.randn(16, 4).to(device)
output = model(x)
print(f"Output shape: {output.shape}")
print(f"Output device: {output.device}")
