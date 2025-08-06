"use client";

import { Mic, Upload } from "lucide-react";
import { useMicrophonePrediction } from "@/hooks/useMicrophonePrediction";
import { useFileUploadPrediction } from "@/hooks/useFileUploadPrediction";
import { PredictionResult } from "./PredictionResult";

type AudioTabProps = {
  fnName: string;
};

export function AudioTab({ fnName }: AudioTabProps) {
  const {
    isRecording,
    audioURL,
    isLoading: micLoading,
    prediction: micPred,
    error: micError,
    startRecording,
    stopRecording,
  } = useMicrophonePrediction(fnName);

  const {
    prediction: uploadPred,
    isLoading: uploadLoading,
    error: uploadError,
    handleFileChange,
  } = useFileUploadPrediction(fnName);

  const prediction = micPred ?? uploadPred;
  const isLoading = micLoading || uploadLoading;
  const error = micError ?? uploadError;

  const accept = ".wav,.mp3,.flac,.m4a";
  const UploadIcon = Upload;

  return (
    <section className="flex flex-col md:flex-row md:space-x-8">
      <div className="w-full md:w-1/2 space-y-8 flex flex-col items-center">
        <button
          onClick={isRecording ? stopRecording : startRecording}
          className={`flex items-center px-6 py-3 font-semibold rounded-lg shadow-md ${
            isRecording
              ? "bg-red-500 text-white hover:bg-red-600"
              : "bg-blue-500 text-white hover:bg-blue-600"
          }`}
          disabled={isLoading}
        >
          <Mic className="w-5 h-5 mr-2" />
          {isRecording ? "Stop Recording" : "Record Voice"}
        </button>

        {audioURL && (
          <audio
            src={audioURL}
            controls
            className="w-full max-w-md mt-4 rounded-lg"
          />
        )}

        <label className="relative flex flex-col items-center justify-center w-full h-48 border-2 border-dashed rounded-lg cursor-pointer bg-gray-50 hover:bg-gray-100">
          <UploadIcon className="w-10 h-10 mb-2 text-gray-400" />
          <p className="mb-1 text-sm text-gray-500">
            <span className="font-semibold">Click to upload</span> or drag and drop
          </p>
          <p className="text-xs text-gray-500">Audio (WAV, MP3, etc.)</p>
          <input
            type="file"
            accept={accept}
            onChange={handleFileChange}
            disabled={isLoading}
            className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
          />
        </label>
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
