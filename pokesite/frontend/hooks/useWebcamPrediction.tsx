"use client";

import { useState, useRef, useEffect, useCallback } from "react";
import { callInferenceAPI, Prediction, IMAGE_FN_NAME } from "@/lib/api";

export function useWebcamPrediction() {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const rafRef = useRef<number>(null);
  const streamRef = useRef<MediaStream>(null);

  const [prediction, setPrediction] = useState<Prediction | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isActive, setIsActive] = useState(false);

  const startWebcam = useCallback(() => {
    setError(null);
    setPrediction(null);
    setIsActive(true);
  }, []);

  const stopWebcam = useCallback(() => {
    setIsActive(false);
  }, []);

  useEffect(() => {
    if (!isActive) {
      streamRef.current?.getTracks().forEach((t) => t.stop());

      cancelAnimationFrame(rafRef.current!);

      return;
    }

    let cancelled = false;

    (async () => {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({
          video: true,
        });
        if (cancelled || !videoRef.current) return;

        streamRef.current = stream;
        videoRef.current.srcObject = stream;
        await videoRef.current.play();

        const loop = async () => {
          if (cancelled || !videoRef.current || !canvasRef.current) return;

          const video = videoRef.current;
          const canvas = canvasRef.current;
          canvas.width = video.videoWidth;
          canvas.height = video.videoHeight;
          canvas.getContext("2d")!.drawImage(video, 0, 0);

          const blob = await new Promise<Blob | null>((resolve) =>
            canvas.toBlob(resolve, "image/png")
          );
          if (blob) {
            try {
              const file = new File([blob], "frame.png", { type: "image/png" });
              const result = await callInferenceAPI(file, IMAGE_FN_NAME);
              setPrediction(result);
            } catch (e: any) {
              console.error("Prediction error:", e);
            }
          }

          rafRef.current = requestAnimationFrame(loop);
        };

        rafRef.current = requestAnimationFrame(loop);
      } catch (e) {
        setError("Could not access webcam. Check permissions.");
        setIsActive(false);
      }
    })();

    return () => {
      cancelled = true;
      streamRef.current?.getTracks().forEach((t) => t.stop());
      cancelAnimationFrame(rafRef.current!);
    };
  }, [isActive]);

  return {
    videoRef,
    canvasRef,
    prediction,
    error,
    isActive,
    startWebcam,
    stopWebcam,
  };
}
