"use client";

import React, { useState } from "react";
import { Mic, Camera } from "lucide-react";
import { AUDIO_FN_NAME, IMAGE_FN_NAME } from "@/lib/api";
import { AudioTab } from "@/components/AudioTab";
import { ImageTab } from "@/components/ImageTab";

type TabId = "audio" | "webcam" | "image";

const TABS_CONFIG = [
  {
    id: "audio",
    label: "Audio",
    Icon: Mic,
    component: <AudioTab fnName={AUDIO_FN_NAME} />,
  },
  {
    id: "image",
    label: "Image",
    Icon: Camera,
    component: <ImageTab fnName={IMAGE_FN_NAME} />,
  },
];

function Tabs({
  activeTab,
  setActiveTab,
}: {
  activeTab: TabId;
  setActiveTab: (tab: TabId) => void;
}) {
  return (
    <div className="my-6 border-b border-gray-200">
      <nav className="-mb-px flex space-x-8" aria-label="Tabs">
        {TABS_CONFIG.map(({ id, label, Icon }) => (
          <button
            key={id}
            onClick={() => setActiveTab(id as TabId)}
            className={`group inline-flex items-center py-4 px-1 border-b-2 font-medium text-sm ${
              activeTab === id
                ? "border-blue-500 text-blue-600"
                : "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
            }`}
          >
            <Icon className="-ml-0.5 mr-2 h-5 w-5" />
            <span className="capitalize">{label}</span>
          </button>
        ))}
      </nav>
    </div>
  );
}

export default function App() {
  const [activeTab, setActiveTab] = useState<TabId>("audio");

  const activeTabContent = TABS_CONFIG.find(
    (tab) => tab.id === activeTab
  )?.component;

  return (
    <div className="min-h-screen font-sans">
      <main className="max-w-4xl mx-auto p-4 sm:p-8">
        <div className="text-center">
          <h1 className="text-5xl sm:text-6xl font-bold font-pokemon text-[#FFCB05]">
            Pokédex
          </h1>
          <p className="mt-2 text-lg text-gray-600">
            Upload audio/image files or use your webcam for real-time
            classification.
          </p>
        </div>

        <Tabs activeTab={activeTab} setActiveTab={setActiveTab} />

        <div className="mt-6">{activeTabContent}</div>
      </main>
    </div>
  );
}
