"use client";

import React, { useState } from "react";
import "./globals.css";

const INFERENCE_ROUTE = "/api/inference";
const AUDIO_FN_NAME = "predict_audio_file";
const IMAGE_FN_NAME = "predict_image_file";

type Prediction = {
  data: any[];
  duration?: number;
};

export default function App() {
  const [audioResult, setAudioResult] = useState<string | null>(null);
  const [imageResult, setImageResult] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Convert File → Base64
  function toBase64(file: File): Promise<string> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve((reader.result as string).split(",")[1]);
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
  }

  async function callSpace(file: File, fnName: string): Promise<Prediction> {
    const b64 = await toBase64(file);
    const resp = await fetch(INFERENCE_ROUTE, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ fnName, file: b64 }),
    });
    if (!resp.ok) {
      const errText = await resp.text();
      throw new Error(errText || "Request failed");
    }
    return resp.json();
  }

  async function onAudioChange(e: React.ChangeEvent<HTMLInputElement>) {
    setError(null);
    setAudioResult(null);
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      const data = await callSpace(file, AUDIO_FN_NAME);
      setAudioResult(JSON.stringify(data));
    } catch (err: any) {
      setError(err.message);
    }
  }

  async function onImageChange(e: React.ChangeEvent<HTMLInputElement>) {
    setError(null);
    setImageResult(null);
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      const data = await callSpace(file, IMAGE_FN_NAME);
      setImageResult(JSON.stringify(data));
    } catch (err: any) {
      setError(err.message);
    }
  }

  return (
    <div className="App">
      <h1>Pokédex</h1>
      {error && <div className="error">Error: {error}</div>}

      <section>
        <h2>Audio Classification</h2>
        <input
          type="file"
          accept=".wav,.mp3,.flac,.m4a"
          onChange={onAudioChange}
        />
        {audioResult && (
          <p className="result">
            Result: <strong>{audioResult}</strong>
          </p>
        )}
      </section>

      <section>
        <h2>Image Classification</h2>
        <input type="file" accept="image/*" onChange={onImageChange} />
        {imageResult && (
          <p className="result">
            Result: <strong>{imageResult}</strong>
          </p>
        )}
      </section>
    </div>
  );
}
