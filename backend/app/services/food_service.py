import csv
import os
from typing import Optional

class FoodService:
    def __init__(self):
        self.food_db = []
        self._load_csv()

    def _load_csv(self):
        # Look for food_db.csv in the same directory as this file
        csv_path = os.path.join(os.path.dirname(__file__), "food_db.csv")
        
        if not os.path.exists(csv_path):
            print(f"CRITICAL: {csv_path} not found!")
            return

        try:
            with open(csv_path, mode="r", encoding="utf-8") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    self.food_db.append({
                        "id": row.get("name", ""), # Using name as ID for simplicity
                        "name": row.get("name", "").strip(),
                        "brand": "Generic",
                        "calories_per_100g": self._safe_float(row.get("calories")),
                        "protein_per_100g": self._safe_float(row.get("protein")),
                        "carbs_per_100g": self._safe_float(row.get("carbs")),
                        "fat_per_100g": self._safe_float(row.get("fat")),
                        "serving_size_g": 100.0,
                        "serving_label": "100g",
                        "image_path": row.get("image", "") # Stores '/foods/rice.jpg'
                    })
            print(f"Loaded {len(self.food_db)} items from your custom CSV.")
        except Exception as e:
            print(f"Error loading CSV: {e}")

    async def search(self, query: str, page: int = 1) -> list[dict]:
        query = query.lower().strip()
        results = [f for f in self.food_db if query in f["name"].lower()]
        
        page_size = 20
        start = (page - 1) * page_size
        return results[start : start + page_size]

    def _safe_float(self, value) -> float:
        try:
            return round(float(value), 2) if value else 0.0
        except (TypeError, ValueError):
            return 0.0

food_service = FoodService()