# Behave

AI-powered behavioral coaching for remote professionals. Uses on-device computer vision and speech analysis to help you improve posture, facial expressions, habits, and communication in real-time.

## Architecture

- **iOS app** (Swift/SwiftUI) — all detection runs on-device via Apple Vision framework (Neural Engine)
- **Backend API** (FastAPI) — auth, data sync, LLM coaching via Claude
- **Deployment** — Shelob on kieleth-sandbox (behave.kieleth.com)

## Detection pipeline

| Detector | Framework | Output |
|---|---|---|
| Body pose | VNDetectHumanBodyPoseRequest | 19 joint points |
| Face landmarks | VNDetectFaceLandmarksRequest | 76 landmarks |
| Hand pose | VNDetectHumanHandPoseRequest | 21 landmarks/hand |
| Speech | SFSpeechRecognizer (on-device) | Real-time transcription |

## Project structure

```
behave/
├── legacy/          # Original Python code (2014)
├── ios/             # SwiftUI iOS app
│   ├── Behave/
│   │   ├── Detection/       # Vision framework detectors
│   │   ├── Classification/  # Behavior classifiers
│   │   ├── Enforcement/     # Alert/rule engine
│   │   ├── Views/           # SwiftUI views
│   │   └── Data/            # Models, persistence
│   └── project.yml          # xcodegen spec
├── backend/         # FastAPI backend
│   ├── app/
│   │   ├── auth/            # Apple Sign-In + JWT
│   │   ├── models/          # SQLAlchemy models
│   │   ├── routers/         # API endpoints
│   │   └── services/        # Claude proxy
│   └── Dockerfile
├── docker-compose.yml
└── shelob.yml
```

## Development

### iOS app
```bash
cd ios
xcodegen generate
open Behave.xcodeproj
```

### Backend (local)
```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8300
```

### Deploy
```
shelob deploy_project behave
```
