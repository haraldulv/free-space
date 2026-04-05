import { NextResponse } from "next/server";

export async function GET() {
  const association = {
    applinks: {
      apps: [],
      details: [
        {
          appID: "3VD2DMBJ6M.no.tuno.app",
          paths: ["/listings/*"],
        },
      ],
    },
  };

  return NextResponse.json(association, {
    headers: {
      "Content-Type": "application/json",
    },
  });
}
