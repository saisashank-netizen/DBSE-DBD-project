import math
from typing import List, Dict, Any
from fastapi import APIRouter
from app.models.pydantic_schemas import CargoClassifyRequest, CargoClassifyResponse

router = APIRouter(prefix="/ai", tags=["Vector Similarity & Logistics AI (CO2)"])

# Pre-defined cargo archetype vectors (Dense semantic representations)
CARGO_EMBEDDING_ARCHETYPES = {
    "perishable_cold_chain": {
        "vector": [0.92, 0.15, 0.85, 0.10, 0.70],
        "category": "Perishable / Temperature Sensitive",
        "recommended_vehicle": "Refrigerated Van",
        "instructions": "Maintain temperature between 2°C and 6°C. Priority dispatch."
    },
    "heavy_machinery_industrial": {
        "vector": [0.12, 0.95, 0.20, 0.90, 0.30],
        "category": "Heavy Industrial Freight",
        "recommended_vehicle": "Multi-axle Heavy Truck",
        "instructions": "Use industrial tie-down straps. Check bridge clearance and weight limits."
    },
    "fragile_electronics": {
        "vector": [0.80, 0.30, 0.90, 0.25, 0.88],
        "category": "Fragile High-Value Electronics",
        "recommended_vehicle": "Shock-Absorbing Van / Container",
        "instructions": "Keep upright, avoid moisture, do not stack more than 2 high."
    },
    "rapid_document_express": {
        "vector": [0.70, 0.05, 0.40, 0.05, 0.95],
        "category": "Express Document / Small Parcel",
        "recommended_vehicle": "Electric Bike / Two-Wheeler Courier",
        "instructions": "Same-day direct delivery. Waterproof pouch required."
    },
    "general_dry_cargo": {
        "vector": [0.50, 0.50, 0.50, 0.50, 0.50],
        "category": "General Dry Freight",
        "recommended_vehicle": "Standard Medium Truck",
        "instructions": "Standard palletization and shrink-wrap."
    }
}

def _text_to_pseudo_vector(text: str, weight: float) -> List[float]:
    """Generates a normalized embedding vector based on cargo keywords and weight."""
    t = text.lower()
    dim1 = 0.9 if any(w in t for w in ["food", "fruit", "milk", "vegetable", "medicine", "vaccine", "cold", "frozen"]) else 0.3
    dim2 = 0.95 if (weight > 100 or any(w in t for w in ["steel", "engine", "motor", "crane", "machine", "generator"])) else 0.2
    dim3 = 0.9 if any(w in t for w in ["glass", "fragile", "laptop", "phone", "screen", "circuit", "delicate"]) else 0.4
    dim4 = 0.85 if weight > 50 else 0.2
    dim5 = 0.95 if any(w in t for w in ["urgent", "express", "document", "passport", "paper", "envelope", "speed"]) else 0.4

    # Normalize vector
    magnitude = math.sqrt(sum(x*x for x in [dim1, dim2, dim3, dim4, dim5]))
    return [x / magnitude for x in [dim1, dim2, dim3, dim4, dim5]]

def _cosine_similarity(vec_a: List[float], vec_b: List[float]) -> float:
    dot = sum(a * b for a, b in zip(vec_a, vec_b))
    mag_a = math.sqrt(sum(a * a for a in vec_a))
    mag_b = math.sqrt(sum(b * b for b in vec_b))
    if mag_a == 0 or mag_b == 0:
        return 0.0
    return dot / (mag_a * mag_b)

@router.post("/classify-cargo", response_model=CargoClassifyResponse)
def classify_cargo_vector(req: CargoClassifyRequest):
    """
    Demonstrates Vector Embedding & Cosine Similarity search (CO2 Vector Database Foundations).
    Calculates similarity between incoming cargo and prototype vectors to recommend vehicle & handling.
    """
    input_vector = _text_to_pseudo_vector(req.cargo_description, req.declared_weight_kg)

    best_match = None
    best_score = -1.0

    for key, archetype in CARGO_EMBEDDING_ARCHETYPES.items():
        sim = _cosine_similarity(input_vector, archetype["vector"])
        if sim > best_score:
            best_score = sim
            best_match = archetype

    return CargoClassifyResponse(
        category=best_match["category"],
        similarity_score=round(best_score, 4),
        recommended_vehicle=best_match["recommended_vehicle"],
        special_handling_instructions=best_match["instructions"]
    )
