import torch
from torchvision.models import resnet18
from torchinfo import summary
import os

device = "mps" if torch.backends.mps.is_available() else "cpu"
print("Using device:", device)

model = resnet18().to(device)

Hw4ai = summary(
    model,
    input_size=(1, 3, 224, 224),
    col_names=["input_size", "output_size", "num_params", "mult_adds"],
    verbose=1
)

# create folder if not exists
os.makedirs("Profiling", exist_ok=True)

with open("Profiling/resnet18_profile.txt", "w") as f:
    f.write(str(Hw4ai))

print("*****Success*****")
