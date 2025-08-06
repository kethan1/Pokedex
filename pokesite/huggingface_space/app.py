import torch
import torchaudio
import torchvision
import gradio as gr

from model_def import AudioCNN, ImageCNN

audio_model = AudioCNN()
audio_model.load_state_dict(torch.load("weights/audio-cnn.pth", map_location="cpu"))
audio_model.eval()

image_model = ImageCNN()
image_model.load_state_dict(torch.load("weights/image-cnn.pth", map_location="cpu"))
image_model.eval()

CLASS_LABELS = [
    "bulbosaur",
    "charmander",
    "gengar",
    "magikarp",
    "mew",
    "pikachu",
    "psyduck",
    "squirtle",
]


def predict_audio_file(wav):
    audio, sr = torchaudio.load(wav)

    # resample to 16kHz
    if sr != 16_000:
        audio = torchaudio.functional.resample(audio, sr, 16_000)

    # convert to mono
    if audio.dim() > 1:
        audio = audio.mean(0, keepdim=True)

    to_mel = torchaudio.transforms.MelSpectrogram(
        sample_rate=16_000, n_mels=64, n_fft=400, hop_length=200
    )
    to_db = torchaudio.transforms.AmplitudeToDB()

    mel = to_db(to_mel(audio))

    # crop / pad to 200 frames
    mel = mel[..., :200]
    if mel.shape[-1] < 200:
        pad = torch.zeros(1, 64, 200 - mel.shape[-1])
        mel = torch.cat([mel, pad], dim=-1)

    mel = mel.unsqueeze(0)  # (1, 1, 64, 200)

    with torch.no_grad():
        logits = audio_model(mel)
        probs = torch.softmax(logits, 1)[0]

    return {k: float(probs[i]) for i, k in enumerate(CLASS_LABELS)}


def predict_image_file(img):
    if img is None:
        return {k: 0.0 for k in CLASS_LABELS}

    img = img.convert("RGB")

    transform = torchvision.transforms.Compose(
        [
            torchvision.transforms.Resize((200, 200)),
            torchvision.transforms.ToTensor(),
            torchvision.transforms.Normalize(
                mean=[0.4960, 0.4695, 0.4262], std=[0.2158, 0.2027, 0.1885]
            ),
        ]
    )

    img = transform(img).unsqueeze(0)

    with torch.no_grad():
        logits = image_model(img)
        probs = torch.softmax(logits, 1)[0]

    return {k: float(probs[i]) for i, k in enumerate(CLASS_LABELS)}


demo = gr.TabbedInterface(
    [
        gr.Interface(
            fn=predict_audio_file, inputs=gr.Audio(type="filepath"), outputs="label", api_name="predict_audio_file"
        ),
        gr.Interface(
            fn=predict_image_file, inputs=gr.Image(type="pil"), outputs="label", api_name="predict_image_file"
        ),
    ],
    tab_names=["Audio", "Image"],
)

if __name__ == "__main__":
    demo.launch()
