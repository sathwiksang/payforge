"""
Train a LightGBM fraud detection model.
Uses synthetic transaction data with realistic distributions.
Exports to both native LightGBM (.txt) and ONNX format for Ruby inference.

Research basis: LightGBM consistently achieves top performance on tabular
fraud detection benchmarks (Kakkar 2025, SSRN).
"""

import lightgbm as lgb
import numpy as np
import pandas as pd
from sklearn.model_selection import StratifiedKFold
from sklearn.metrics import roc_auc_score, average_precision_score
import shap
import json
import os
import sys


FEATURE_NAMES = [
    "amount_cents",
    "log_amount",
    "hour_of_day",
    "day_of_week",
    "is_weekend",
    "is_business_hours",
    "card_brand",
    "currency",
    "tx_count_5min",
    "tx_count_1hr",
    "tx_count_24hr",
    "sum_amount_1hr",
    "sum_amount_24hr",
    "distinct_merchants_24hr",
    "merchant_avg_tx",
    "merchant_tx_count_30d",
    "merchant_chargeback_rate",
    "merchant_days_active",
    "merchant_risk_tier",
    "amount_deviation",
    "time_since_last_tx",
    "is_first_tx",
    "distance",
]


def business_hour_dist():
    """Probability distribution for legitimate transaction hours."""
    probs = np.zeros(24)
    # Peak during business hours 9-17
    for h in range(9, 18):
        probs[h] = 0.08
    # Some evening activity
    for h in range(18, 22):
        probs[h] = 0.04
    # Low overnight
    for h in list(range(0, 9)) + [22, 23]:
        probs[h] = 0.01
    return probs / probs.sum()


def fraud_hour_dist():
    """Probability distribution for fraudulent transaction hours."""
    probs = np.zeros(24)
    # Fraudsters are more active at night
    for h in range(0, 6):
        probs[h] = 0.06
    for h in range(6, 24):
        probs[h] = 0.038
    return probs / probs.sum()


def generate_synthetic_data(n_samples=100_000, fraud_rate=0.02):
    """Generate realistic synthetic transaction data for training."""
    np.random.seed(42)
    n_fraud = int(n_samples * fraud_rate)
    n_legit = n_samples - n_fraud

    # Legitimate transactions
    legit = pd.DataFrame(
        {
            "amount_cents": np.random.lognormal(mean=7, sigma=1.5, size=n_legit)
            .astype(int)
            .clip(100, 5_000_000),
            "log_amount": np.zeros(n_legit),
            "hour_of_day": np.random.choice(
                range(24), size=n_legit, p=business_hour_dist()
            ),
            "day_of_week": np.random.choice(range(7), size=n_legit),
            "is_weekend": np.zeros(n_legit),
            "is_business_hours": np.zeros(n_legit),
            "card_brand": np.random.choice(
                [0, 1, 2, 3], size=n_legit, p=[0.5, 0.3, 0.15, 0.05]
            ),
            "currency": np.zeros(n_legit),
            "tx_count_5min": np.random.poisson(0.3, n_legit),
            "tx_count_1hr": np.random.poisson(2, n_legit),
            "tx_count_24hr": np.random.poisson(5, n_legit),
            "sum_amount_1hr": np.random.lognormal(8, 1.5, n_legit).astype(int),
            "sum_amount_24hr": np.random.lognormal(9, 1.5, n_legit).astype(int),
            "distinct_merchants_24hr": np.random.poisson(2, n_legit),
            "merchant_avg_tx": np.random.lognormal(7, 1, n_legit).astype(int),
            "merchant_tx_count_30d": np.random.poisson(500, n_legit),
            "merchant_chargeback_rate": np.random.beta(1, 100, n_legit),
            "merchant_days_active": np.random.uniform(30, 3000, n_legit).astype(int),
            "merchant_risk_tier": np.random.choice(
                [0, 1, 2], size=n_legit, p=[0.7, 0.25, 0.05]
            ),
            "amount_deviation": np.random.exponential(0.5, n_legit),
            "time_since_last_tx": np.random.exponential(3600, n_legit),
            "is_first_tx": np.random.choice(
                [0, 1], size=n_legit, p=[0.95, 0.05]
            ),
            "distance": np.random.exponential(50, n_legit),
            "is_fraud": np.zeros(n_legit, dtype=int),
        }
    )

    # Fraudulent transactions (different distributions)
    fraud = pd.DataFrame(
        {
            "amount_cents": np.random.lognormal(mean=8.5, sigma=2, size=n_fraud)
            .astype(int)
            .clip(100, 5_000_000),
            "log_amount": np.zeros(n_fraud),
            "hour_of_day": np.random.choice(
                range(24), size=n_fraud, p=fraud_hour_dist()
            ),
            "day_of_week": np.random.choice(range(7), size=n_fraud),
            "is_weekend": np.zeros(n_fraud),
            "is_business_hours": np.zeros(n_fraud),
            "card_brand": np.random.choice(
                [0, 1, 2, 3], size=n_fraud, p=[0.4, 0.3, 0.2, 0.1]
            ),
            "currency": np.zeros(n_fraud),
            "tx_count_5min": np.random.poisson(3, n_fraud),
            "tx_count_1hr": np.random.poisson(8, n_fraud),
            "tx_count_24hr": np.random.poisson(15, n_fraud),
            "sum_amount_1hr": np.random.lognormal(10, 2, n_fraud).astype(int),
            "sum_amount_24hr": np.random.lognormal(11, 2, n_fraud).astype(int),
            "distinct_merchants_24hr": np.random.poisson(5, n_fraud),
            "merchant_avg_tx": np.random.lognormal(7, 1, n_fraud).astype(int),
            "merchant_tx_count_30d": np.random.poisson(500, n_fraud),
            "merchant_chargeback_rate": np.random.beta(3, 50, n_fraud),
            "merchant_days_active": np.random.uniform(1, 500, n_fraud).astype(int),
            "merchant_risk_tier": np.random.choice(
                [0, 1, 2], size=n_fraud, p=[0.3, 0.4, 0.3]
            ),
            "amount_deviation": np.random.exponential(3, n_fraud),
            "time_since_last_tx": np.random.exponential(300, n_fraud),
            "is_first_tx": np.random.choice(
                [0, 1], size=n_fraud, p=[0.7, 0.3]
            ),
            "distance": np.random.exponential(500, n_fraud),
            "is_fraud": np.ones(n_fraud, dtype=int),
        }
    )

    df = pd.concat([legit, fraud], ignore_index=True).sample(
        frac=1, random_state=42
    )
    df["log_amount"] = np.log(1 + df["amount_cents"].astype(float))
    df["is_weekend"] = df["day_of_week"].isin([5, 6]).astype(int)
    df["is_business_hours"] = (
        df["hour_of_day"].between(9, 17) & ~df["is_weekend"].astype(bool)
    ).astype(int)

    return df


def train_and_export(n_samples=200_000):
    """Train LightGBM with 5-fold stratified CV, export to native format."""
    print(f"Generating {n_samples:,} synthetic transactions...")
    df = generate_synthetic_data(n_samples=n_samples, fraud_rate=0.02)

    feature_cols = [c for c in df.columns if c != "is_fraud"]
    X = df[feature_cols].values
    y = df["is_fraud"].values

    print(f"Features: {len(feature_cols)}, Fraud rate: {y.mean():.4f}")

    # LightGBM parameters (tuned for fraud detection)
    params = {
        "objective": "binary",
        "metric": "auc",
        "learning_rate": 0.05,
        "num_leaves": 63,
        "max_depth": 8,
        "min_child_samples": 50,
        "subsample": 0.8,
        "colsample_bytree": 0.8,
        "scale_pos_weight": (1 - 0.02) / 0.02,
        "verbose": -1,
        "n_estimators": 500,
        "early_stopping_rounds": 50,
    }

    # 5-fold stratified cross-validation
    skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    auc_scores = []
    ap_scores = []

    print("\nTraining with 5-fold stratified CV...")
    for fold, (train_idx, val_idx) in enumerate(skf.split(X, y)):
        X_train, X_val = X[train_idx], X[val_idx]
        y_train, y_val = y[train_idx], y[val_idx]

        model = lgb.LGBMClassifier(**params)
        model.fit(X_train, y_train, eval_set=[(X_val, y_val)])

        preds = model.predict_proba(X_val)[:, 1]
        auc = roc_auc_score(y_val, preds)
        ap = average_precision_score(y_val, preds)
        auc_scores.append(auc)
        ap_scores.append(ap)
        print(f"  Fold {fold + 1}: AUC={auc:.4f}, AP={ap:.4f}")

    mean_auc = np.mean(auc_scores)
    std_auc = np.std(auc_scores)
    print(f"\nMean AUC: {mean_auc:.4f} (+/- {std_auc:.4f})")
    print(f"Mean AP:  {np.mean(ap_scores):.4f} (+/- {np.std(ap_scores):.4f})")

    if mean_auc < 0.95:
        print(f"\nWARNING: AUC {mean_auc:.4f} below target 0.95")

    # Train final model on full data
    print("\nTraining final model on full dataset...")
    final_params = {**params, "n_estimators": 300}
    del final_params["early_stopping_rounds"]
    final_model = lgb.LGBMClassifier(**final_params)
    final_model.fit(X, y)

    # Export paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = os.path.join(script_dir, "..", "..", "backend", "ml_models")
    output_dir = os.path.normpath(output_dir)
    os.makedirs(output_dir, exist_ok=True)

    # Export native LightGBM format (for Ruby lightgbm gem)
    txt_path = os.path.join(output_dir, "fraud_lgbm.txt")
    final_model.booster_.save_model(txt_path)
    # Fix pandas_categorical for Ruby lightgbm gem compatibility
    with open(txt_path, "r") as f:
        content = f.read()
    content = content.replace("pandas_categorical:null", "pandas_categorical:[]")
    with open(txt_path, "w") as f:
        f.write(content)
    print(f"Saved native LightGBM model: {txt_path}")

    # Export ONNX format (for Ruby onnxruntime gem)
    try:
        import onnxmltools
        from onnxmltools.convert import convert_lightgbm
        from onnxconverter_common.data_types import FloatTensorType

        initial_type = [("features", FloatTensorType([None, len(feature_cols)]))]
        onnx_model = convert_lightgbm(final_model, initial_types=initial_type)
        onnx_path = os.path.join(output_dir, "fraud_lgbm.onnx")
        with open(onnx_path, "wb") as f:
            f.write(onnx_model.SerializeToString())
        print(f"Saved ONNX model: {onnx_path}")
    except ImportError:
        print("ONNX export skipped (onnxmltools not installed)")

    # Feature importance
    importance = final_model.feature_importances_
    feat_imp = sorted(
        zip(feature_cols, importance), key=lambda x: x[1], reverse=True
    )
    print("\nTop 10 feature importances:")
    for name, imp in feat_imp[:10]:
        print(f"  {name}: {imp}")

    # Save model metadata
    metadata = {
        "model_version": "1.0.0",
        "trained_at": pd.Timestamp.now().isoformat(),
        "n_features": len(feature_cols),
        "feature_names": feature_cols,
        "mean_auc": round(float(mean_auc), 4),
        "std_auc": round(float(std_auc), 4),
        "mean_ap": round(float(np.mean(ap_scores)), 4),
        "n_training_samples": len(X),
        "fraud_rate": round(float(y.mean()), 4),
        "params": {k: v for k, v in params.items() if k != "verbose"},
        "feature_importance": {name: int(imp) for name, imp in feat_imp},
    }
    metadata_path = os.path.join(output_dir, "fraud_lgbm_metadata.json")
    with open(metadata_path, "w") as f:
        json.dump(metadata, f, indent=2)
    print(f"Saved metadata: {metadata_path}")

    print(f"\nDone! Models exported to {output_dir}")
    return final_model, mean_auc


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 200_000
    model, auc = train_and_export(n_samples=n)
    if auc >= 0.95:
        print(f"\nSUCCESS: AUC {auc:.4f} >= 0.95 target")
    else:
        print(f"\nWARNING: AUC {auc:.4f} < 0.95 target")
        sys.exit(1)
