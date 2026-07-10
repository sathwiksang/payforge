from fastapi import APIRouter, Request
import time
import json
import os

router = APIRouter()


@router.get("/")
async def health(req: Request):
    uptime = time.time() - req.app.state.start_time

    models_loaded = {
        "lightgbm": hasattr(req.app.state, "lightgbm_model")
        and req.app.state.lightgbm_model is not None,
        "shap_explainer": hasattr(req.app.state, "shap_explainer")
        and req.app.state.shap_explainer is not None,
        "anomaly_detector": hasattr(req.app.state, "anomaly_detector")
        and req.app.state.anomaly_detector is not None,
    }

    return {
        "status": "healthy",
        "service": "ml_sidecar",
        "uptime_seconds": round(uptime, 2),
        "models_loaded": models_loaded,
    }


@router.get("/model-metadata")
async def model_metadata():
    metadata_path = os.path.join(
        os.path.dirname(__file__),
        "..",
        "..",
        "..",
        "backend",
        "ml_models",
        "fraud_lgbm_metadata.json",
    )
    metadata_path = os.path.normpath(metadata_path)

    if not os.path.exists(metadata_path):
        return {"error": "Model metadata not found", "path": metadata_path}

    with open(metadata_path) as f:
        metadata = json.load(f)

    return metadata
