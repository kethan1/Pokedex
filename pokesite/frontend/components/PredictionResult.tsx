import { Prediction, SinglePrediction } from "@/lib/api";

export function ProbabilityBars({
  probabilities,
}: {
  probabilities: SinglePrediction[];
}) {
  const sortedProbs = probabilities
    .map((prob) => [prob.label, prob.confidence] as [string, number])
    .sort((a, b) => b[1] - a[1]);

  return (
    <div className="w-full mt-4 space-y-2">
      {sortedProbs.map(([className, prob]) => (
        <div
          key={className}
          className="w-full bg-gray-200 rounded-full h-6 relative"
        >
          <div
            className="bg-blue-500 h-full flex items-center justify-start rounded-full"
            style={{ width: `${prob * 100}%` }}
          >
            <span className="text-white font-medium text-sm pl-3 pr-2 whitespace-nowrap">
              {className}
            </span>
          </div>
          <span className="absolute top-1/2 right-3 -translate-y-1/2 text-sm font-semibold text-gray-700">
            {(prob * 100).toFixed(1)}%
          </span>
        </div>
      ))}
    </div>
  );
}

export function PredictionResult({
  prediction,
  isLoading,
}: {
  prediction: Prediction | null;
  isLoading: boolean;
}) {
  if (isLoading) {
    return (
      <div className="mt-6 text-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-gray-900 mx-auto"></div>
        <p className="mt-2 text-gray-600">Analyzing...</p>
      </div>
    );
  }

  if (!prediction) return null;

  if ("error" in prediction) {
    return (
      <div className="mt-6 p-4 bg-red-100 border border-red-400 text-red-700 rounded-lg">
        {prediction.error}
      </div>
    );
  }

  const mostProbableConfidence = prediction.confidences.filter((det) => {
    if (det.label === prediction.label) {
      return det;
    }
  })[0].confidence;

  return (
    <div className="mt-6 p-4 bg-green-50 border border-green-300 rounded-lg w-full">
      <p className="text-lg">
        <strong className="font-semibold">Predicted Class:</strong>
        <span className="ml-2 text-green-800 bg-green-200 px-3 py-1 rounded-full">
          {prediction.label}
        </span>
      </p>
      <p className="mt-2 text-lg">
        <strong className="font-semibold">Confidence:</strong>
        <span className="ml-2">
          {(mostProbableConfidence * 100).toFixed(2)}%
        </span>
      </p>
      <ProbabilityBars probabilities={prediction.confidences} />
    </div>
  );
}
