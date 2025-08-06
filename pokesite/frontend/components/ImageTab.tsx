"use client";

import { Camera, Upload } from "lucide-react";
import { useWebcamPrediction } from "@/hooks/useWebcamPrediction";
import { useFileUploadPrediction } from "@/hooks/useFileUploadPrediction";
import { PredictionResult } from "./PredictionResult";

type ImageTabProps = {
  fnName: string;
};

export function ImageTab({ fnName }: ImageTabProps) {
  const {
    prediction: camPred,
    isActive: camActive,
    error: camError,
    startWebcam,
    stopWebcam,
    videoRef,
    canvasRef,
  } = useWebcamPrediction();

  const {
    prediction: upPred,
    isLoading: upLoading,
    error: upError,
    handleFileChange,
  } = useFileUploadPrediction(fnName);

  const prediction = upPred ?? camPred;
  const isLoading  = upLoading;
  const error      = upError ?? camError;

  const accept = "image/*";
  const UploadIcon = Upload;
  const label = "Image (PNG, JPG, etc.)";

  return (
    <section className="flex flex-col md:flex-row md:space-x-8">
      <div className="w-full md:w-1/2 space-y-8">
        <div className="flex flex-col items-center">
          <div className="w-full max-w-md relative">
            <video
              ref={videoRef}
              autoPlay
              playsInline
              muted
              className={`w-full rounded-lg shadow-lg bg-black ${
                camActive ? "block" : "hidden"
              }`}
            />
            <canvas ref={canvasRef} className="hidden" />

            {!camActive && (
              <div className="h-60 flex flex-col justify-center items-center bg-gray-100 rounded-lg border-2 border-dashed">
                <Camera className="w-12 h-12 text-gray-400 mb-3" />
                <button
                  onClick={startWebcam}
                  className="px-5 py-2 bg-green-500 text-white font-semibold rounded-lg hover:bg-green-600"
                >
                  Start Camera
                </button>
              </div>
            )}
          </div>
          {camActive && (
            <button
              onClick={stopWebcam}
              className="mt-4 px-5 py-2 bg-red-500 text-white font-semibold rounded-lg hover:bg-red-600"
            >
              Stop Camera
            </button>
          )}
        </div>

        <div>
          <label className="relative flex flex-col items-center justify-center w-full h-48 border-2 border-dashed rounded-lg cursor-pointer bg-gray-50 hover:bg-gray-100">
            <UploadIcon className="w-10 h-10 mb-2 text-gray-400" />
            <p className="mb-1 text-sm text-gray-500">
              <span className="font-semibold">Click to upload</span> or drag and drop
            </p>
            <p className="text-xs text-gray-500">{label}</p>
            <input
              type="file"
              accept={accept}
              onChange={handleFileChange}
              disabled={upLoading}
              className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
            />
          </label>
        </div>
      </div>

      <div className="w-full md:w-1/2 mt-8 md:mt-0">
        {error && (
          <div className="mb-4 p-3 bg-red-100 border border-red-400 text-red-700 rounded-lg">
            Error: {error}
          </div>
        )}

        <PredictionResult prediction={prediction} isLoading={isLoading} />

        {!prediction && !isLoading && (
          <p className="text-center text-gray-500 mt-4">
            Waiting for prediction…
          </p>
        )}
      </div>
    </section>
  );
}
