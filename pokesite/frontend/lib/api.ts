export const INFERENCE_ROUTE = "/api/inference";
export const AUDIO_FN_NAME = "predict_audio_file";
export const IMAGE_FN_NAME = "predict_image_file";

export type SinglePrediction = {
  label: string;
  confidence: number;
};

export type Prediction =
  | {
      label: string;
      confidences: SinglePrediction[];
    }
  | { error: string };

const toBase64 = (file: File): Promise<string> =>
  new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve((reader.result as string).split(",")[1]);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });

export const callInferenceAPI = async (
  file: File,
  fnName: string
): Promise<Prediction> => {
  const base64File = await toBase64(file);
  const response = await fetch(INFERENCE_ROUTE, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ fnName, file: base64File }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(errorText || "An unknown error occurred during inference.");
  }

  const json = await response.json();

  console.log("Inference API response:", json);

  if (
    !json ||
    typeof json !== "object" ||
    !("data" in json || "error" in json)
  ) {
    throw new Error("Invalid response format from inference API.");
  }

  if ("data" in json) {
    return json["data"][0] as Prediction;
  }

  return json;
};
