from fastapi import APIRouter, Request, HTTPException
from pydantic import BaseModel

try:
    from river import anomaly, compose, preprocessing
    RIVER_AVAILABLE = True
except ImportError:
    RIVER_AVAILABLE = False

router = APIRouter()


class ScoreRequest(BaseModel):
    features: list[float]


class ScoreResponse(BaseModel):
    score: float
    decision: str
    model_version: str


class AnomalyRequest(BaseModel):
    features: dict[str, float]


class AnomalyResponse(BaseModel):
    anomaly_score: float
    is_anomaly: bool
    model_observations: int
    detector: str


class StreamingAnomalyDetector:
    """
    Half-Space Trees — online anomaly detection.
    Runs in constant memory, adapts to concept drift.
    Research: Tan et al. (2011), Hannák (2023), Wiley Statistical Analysis & Data Mining.
    """

    def __init__(self, window_size: int = 1000, n_trees: int = 100):
        if not RIVER_AVAILABLE:
            self.model = None
            self.transaction_count = 0
            return

        self.model = compose.Pipeline(
            preprocessing.StandardScaler(),
            anomaly.HalfSpaceTrees(
                n_trees=n_trees,
                height=8,
                window_size=window_size,
                seed=42,
            ),
        )
        self.transaction_count = 0

    def score_and_learn(self, features: dict) -> dict:
        """Score a transaction AND learn from it (online learning)."""
        if self.model is None:
            return {
                "anomaly_score": 0.0,
                "is_anomaly": False,
                "model_observations": 0,
                "detector": "unavailable",
            }

        self.transaction_count += 1
        anomaly_score = self.model.score_one(features)
        self.model.learn_one(features)

        return {
            "anomaly_score": round(anomaly_score, 6),
            "is_anomaly": anomaly_score > 0.7,
            "model_observations": self.transaction_count,
            "detector": "half_space_trees",
        }


@router.post("/predict", response_model=ScoreResponse)
async def predict(request: ScoreRequest, req: Request):
    if not hasattr(req.app.state, "lightgbm_model") or req.app.state.lightgbm_model is None:
        raise HTTPException(status_code=503, detail="LightGBM model not loaded")

    import numpy as np

    model = req.app.state.lightgbm_model
    features = np.array([request.features])
    proba = model.predict_proba(features)[0][1]

    decision = "block" if proba >= 0.85 else ("review" if proba >= 0.60 else "pass")

    return ScoreResponse(
        score=round(float(proba), 4),
        decision=decision,
        model_version=getattr(req.app.state, "model_version", "unknown"),
    )


@router.post("/anomaly", response_model=AnomalyResponse)
async def anomaly_score(request: AnomalyRequest, req: Request):
    if not hasattr(req.app.state, "anomaly_detector") or req.app.state.anomaly_detector is None:
        raise HTTPException(status_code=503, detail="Anomaly detector not initialized")

    detector: StreamingAnomalyDetector = req.app.state.anomaly_detector
    result = detector.score_and_learn(request.features)
    return AnomalyResponse(**result)
