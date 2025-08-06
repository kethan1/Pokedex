"use client";

import { useState } from "react";
import { callInferenceAPI, Prediction } from "@/lib/api";

export function useFileUploadPrediction(fnName: string) {
  const [prediction, setPrediction] = useState<Prediction | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    setError(null);
    setPrediction(null);
    setIsLoading(true);

    const file = e.target.files?.[0];
    if (!file) {
      setIsLoading(false);
      return;
    }

    try {
      const result = await callInferenceAPI(file, fnName);
      setPrediction(result);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setIsLoading(false);

      e.target.value = "";
    }
  };

  return { prediction, isLoading, error, handleFileChange };
};
