from fastapi import FastAPI
from contextlib import asynccontextmanager
import time
import os
import logging

from api.routes import explain, scoring, health

logger = logging.getLogger("payforge.ml_sidecar")


def load_lightgbm_model():
    """Load LightGBM model from saved file."""
    model_path = os.path.join(
        os.path.dirname(__file__), "..", "..", "backend", "ml_models", "fraud_lgbm.txt"
    )
    model_path = os.path.normpath(model_path)

    if not os.path.exists(model_path):
        logger.warning(f"LightGBM model not found at {model_path}")
        return None

    import lightgbm as lgb

    booster = lgb.Booster(model_file=model_path)

    # Wrap in sklearn-compatible interface for predict_proba
    class BoosterWrapper:
        def __init__(self, booster):
            self.booster = booster

        def predict_proba(self, X):
            import numpy as np

            preds = self.booster.predict(X)
            return np.column_stack([1 - preds, preds])

        def predict(self, X):
            return self.booster.predict(X)

    logger.info(f"LightGBM model loaded from {model_path}")
    return BoosterWrapper(booster)


def load_shap_explainer(model):
    """Load SHAP TreeExplainer for the model."""
    if model is None:
        return None

    try:
        import shap

        explainer = shap.TreeExplainer(model.booster)
        logger.info("SHAP TreeExplainer loaded")
        return explainer
    except Exception as e:
        logger.error(f"Failed to load SHAP explainer: {e}")
        return None


def load_anomaly_detector():
    """Initialize streaming anomaly detector."""
    detector = scoring.StreamingAnomalyDetector(window_size=1000, n_trees=100)
    logger.info("Streaming anomaly detector initialized (Half-Space Trees)")
    return detector


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.start_time = time.time()

    # Load models at startup
    app.state.lightgbm_model = load_lightgbm_model()
    app.state.shap_explainer = load_shap_explainer(app.state.lightgbm_model)
    app.state.anomaly_detector = load_anomaly_detector()
    app.state.model_version = "1.0.0"

    logger.info("ML Sidecar started — all models loaded")
    yield
    logger.info("ML Sidecar shutting down")


app = FastAPI(
    title="PayForge ML Sidecar",
    description="Fraud scoring, SHAP explanations, streaming anomaly detection",
    version="1.0.0",
    lifespan=lifespan,
)

app.include_router(scoring.router, prefix="/score", tags=["scoring"])
app.include_router(explain.router, prefix="/explain", tags=["explain"])
app.include_router(health.router, prefix="/health", tags=["health"])


@app.get("/")
async def root():
    return {"service": "PayForge ML Sidecar", "version": "1.0.0"}
