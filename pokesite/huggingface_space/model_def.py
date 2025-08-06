import torch
import torch.nn as nn


class AudioCNN(nn.Module):
    def __init__(self):
        super().__init__()
        self.conv1 = nn.Conv2d(in_channels=1, out_channels=16, kernel_size=3, padding=1)
        self.batchNorm1 = nn.BatchNorm2d(16)
        self.pool1 = nn.MaxPool2d(kernel_size=2, stride=2)

        self.conv2 = nn.Conv2d(
            in_channels=16, out_channels=32, kernel_size=3, padding=1
        )
        self.batchNorm2 = nn.BatchNorm2d(32)
        self.pool2 = nn.MaxPool2d(kernel_size=2, stride=2)

        self.conv3 = nn.Conv2d(
            in_channels=32, out_channels=64, kernel_size=3, padding=1
        )
        self.batchNorm3 = nn.BatchNorm2d(64)
        self.pool3 = nn.MaxPool2d(kernel_size=2, stride=2)

        self.conv4 = nn.Conv2d(
            in_channels=64, out_channels=128, kernel_size=3, padding=1
        )
        self.batchNorm4 = nn.BatchNorm2d(128)

        self.fc1 = nn.Linear(128 * 8 * 25, 512)
        self.fc2 = nn.Linear(512, 256)
        self.dropout = nn.Dropout(0.1)
        self.fc3 = nn.Linear(256, 8)

    def forward(self, x):
        x = torch.relu(self.batchNorm1(self.conv1(x)))
        x = self.pool1(x)
        x = torch.relu(self.batchNorm2(self.conv2(x)))
        x = self.pool2(x)
        x = torch.relu(self.batchNorm3(self.conv3(x)))
        x = self.pool3(x)
        x = torch.relu(self.batchNorm4(self.conv4(x)))
        x = x.view(-1, 128 * 8 * 25)
        x = torch.relu(self.fc1(x))
        x = self.dropout(x)
        x = torch.relu(self.fc2(x))
        x = self.dropout(x)
        x = self.fc3(x)
        return x


class ImageCNN(nn.Module):
    def __init__(self):
        super().__init__()
        self.conv1 = nn.Conv2d(in_channels=3, out_channels=16, kernel_size=3, padding=1)
        self.batchNorm1 = nn.BatchNorm2d(16)
        self.pool1 = nn.MaxPool2d(kernel_size=2, stride=2)

        self.conv2 = nn.Conv2d(
            in_channels=16, out_channels=32, kernel_size=3, padding=1
        )
        self.batchNorm2 = nn.BatchNorm2d(32)
        self.pool2 = nn.MaxPool2d(kernel_size=2, stride=2)

        self.conv3 = nn.Conv2d(
            in_channels=32, out_channels=64, kernel_size=3, padding=1
        )
        self.batchNorm3 = nn.BatchNorm2d(64)
        self.pool3 = nn.MaxPool2d(kernel_size=2, stride=2)

        self.conv4 = nn.Conv2d(
            in_channels=64, out_channels=128, kernel_size=3, padding=1
        )
        self.batchNorm4 = nn.BatchNorm2d(128)
        self.pool4 = nn.MaxPool2d(kernel_size=2, stride=2)

        self.fc1 = nn.Linear(18432, 256)
        self.dropout = nn.Dropout(0.5)
        self.fc2 = nn.Linear(256, 8)

    def forward(self, x):
        x = torch.relu(self.batchNorm1(self.conv1(x)))

        x = self.pool1(x)

        x = torch.relu(self.batchNorm2(self.conv2(x)))
        x = self.pool2(x)

        x = torch.relu(self.batchNorm3(self.conv3(x)))
        x = self.pool3(x)

        x = torch.relu(self.batchNorm4(self.conv4(x)))
        x = self.pool4(x)

        x = x.view(-1, 18432)

        x = torch.relu(self.fc1(x))
        x = self.dropout(x)
        x = self.fc2(x)
        return x
