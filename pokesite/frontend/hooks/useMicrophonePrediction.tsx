"use client";

import { useState, useRef, useCallback, useEffect } from "react";
import { callInferenceAPI, Prediction } from "@/lib/api";

export function useMicrophonePrediction(fnName: string) {
  const [isRecording, setIsRecording] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [prediction, setPrediction] = useState<Prediction | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [audioURL, setAudioURL] = useState<string | null>(null);

  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const chunksRef = useRef<Blob[]>([]);

  const startRecording = useCallback(async () => {
    setError(null);
    setPrediction(null);

    if (!navigator.mediaDevices?.getUserMedia) {
      setError("MediaDevices API not supported in this browser");
      return;
    }

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;

      const mr = new MediaRecorder(stream);
      mediaRecorderRef.current = mr;
      chunksRef.current = [];

      mr.ondataavailable = (e) => {
        if (e.data.size > 0) {
          chunksRef.current.push(e.data);
        }
      };

      mr.start();
      setIsRecording(true);
    } catch (err: any) {
      setError(
        err instanceof Error
          ? err.message
          : "Could not access microphone. Check permissions."
      );
    }
  }, []);

  const stopRecording = useCallback(() => {
    if (mediaRecorderRef.current?.state !== "recording") return;

    mediaRecorderRef.current.onstop = async () => {
      setIsRecording(false);
      setIsLoading(true);

      const blob = new Blob(chunksRef.current, { type: "audio/webm" });

      if (audioURL) {
        URL.revokeObjectURL(audioURL);
      }
      const url = URL.createObjectURL(blob);
      setAudioURL(url);

      const file = new File([blob], "recording.webm", { type: "audio/webm" });

      try {
        const result = await callInferenceAPI(file, fnName);
        setPrediction(result);
      } catch (err: any) {
        setError(
          err instanceof Error ? err.message : "Inference call failed"
        );
      } finally {
        setIsLoading(false);

        streamRef.current?.getTracks().forEach((t) => t.stop());
        mediaRecorderRef.current = null;
        streamRef.current = null;
      }
    };

    mediaRecorderRef.current.stop();
  }, [fnName, audioURL]);

  useEffect(() => {
    return () => {
      if (mediaRecorderRef.current?.state === "recording") {
        mediaRecorderRef.current.stop();
      }
      streamRef.current?.getTracks().forEach((t) => t.stop());
      if (audioURL) {
        URL.revokeObjectURL(audioURL);
      }
    };
  }, [audioURL]);

  return {
    isRecording,
    isLoading,
    prediction,
    error,
    audioURL,
    startRecording,
    stopRecording,
  };
}
