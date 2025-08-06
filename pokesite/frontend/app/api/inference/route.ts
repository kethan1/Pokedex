import { NextRequest, NextResponse } from "next/server";
import { Client, handle_file } from "@gradio/client";

const SPACE_URL = process.env.NEXT_PUBLIC_HF_SPACE_URL;
const HF_TOKEN = process.env.NEXT_PUBLIC_HF_TOKEN;

export async function POST(request: NextRequest) {
  if (!SPACE_URL) {
    return NextResponse.json(
      { error: "HF_SPACE_URL environment variable is not set" },
      { status: 500 }
    );
  }

  try {
    const app = await Client.connect(SPACE_URL, {
      hf_token: (HF_TOKEN && HF_TOKEN.startsWith("hf_")) ? HF_TOKEN as `hf_${string}` : undefined,
    });

    const { fnName, file: fileBase64 } = await request.json();
    if (typeof fnName !== "string" || typeof fileBase64 !== "string") {
      return NextResponse.json({ error: "Invalid payload" }, { status: 400 });
    }

    const buffer = Buffer.from(fileBase64, "base64");
    const fileRef = handle_file(buffer);

    const result = await app.predict(`${fnName}`, [fileRef]);

    return NextResponse.json(result);
  } catch (err: any) {
    console.error(err);
    return NextResponse.json(
      { error: err.message || "Internal error" },
      { status: 500 }
    );
  }
}
