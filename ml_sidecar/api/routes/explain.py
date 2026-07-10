from fastapi import APIRouter, Request, HTTPException
from pydantic import BaseModel
import numpy as np

router = APIRouter()

FEATURE_NAMES = [
    "amount_cents", "log_amount", "hour_of_day", "day_of_week",
    "is_weekend", "is_business_hours", "card_brand", "currency",
    "tx_count_5min", "tx_count_1hr", "tx_count_24hr",
    "sum_amount_1hr", "sum_amount_24hr", "distinct_merchants_24hr",
    "merchant_avg_tx", "merchant_tx_count_30d", "merchant_chargeback_rate",
    "merchant_days_active", "merchant_risk_tier",
    "amount_deviation", "time_since_last_tx", "is_first_tx", "distance",
]


class ExplainRequest(BaseModel):
    features: list[float]


class ExplainResponse(BaseModel):
    shap_values: dict[str, float]
    base_value: float
    prediction: float
    top_contributors: list[dict]


@router.post("/", response_model=ExplainResponse)
async def explain(request: ExplainRequest, req: Request):
    if not hasattr(req.app.state, "shap_explainer") or req.app.state.shap_explainer is None:
        raise HTTPException(status_code=503, detail="SHAP explainer not loaded")

    if len(request.features) != len(FEATURE_NAMES):
        raise HTTPException(
            status_code=422,
            detail=f"Expected {len(FEATURE_NAMES)} features, got {len(request.features)}",
        )

    explainer = req.app.state.shap_explainer
    model = req.app.state.lightgbm_model
    features = np.array([request.features])

    # TreeSHAP: exact Shapley values for tree models (~10ms)
    shap_values = explainer.shap_values(features)
    # Handle binary classification output
    if isinstance(shap_values, list):
        shap_vals = shap_values[1][0]  # Class 1 (fraud) SHAP values
    else:
        shap_vals = shap_values[0]

    base_value = explainer.expected_value
    if isinstance(base_value, (list, np.ndarray)):
        base_value = base_value[1]  # Class 1 base value

    # Build named SHAP map
    shap_map = {
        name: round(float(val), 6) for name, val in zip(FEATURE_NAMES, shap_vals)
    }

    # Top contributors (sorted by absolute impact)
    top = sorted(
        [
            {
                "feature": name,
                "value": float(request.features[i]),
                "shap_value": round(float(shap_vals[i]), 6),
                "direction": "increases_risk" if shap_vals[i] > 0 else "decreases_risk",
            }
            for i, name in enumerate(FEATURE_NAMES)
        ],
        key=lambda x: abs(x["shap_value"]),
        reverse=True,
    )[:10]

    prediction = float(model.predict_proba(features)[0][1])

    return ExplainResponse(
        shap_values=shap_map,
        base_value=round(float(base_value), 6),
        prediction=round(prediction, 4),
        top_contributors=top,
    )
