from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import ensure_assessment_schema
from app.routes.assessment import router as assessment_router


@asynccontextmanager
async def lifespan(_app):
	ensure_assessment_schema()
	yield


app = FastAPI(
	title="Diabetes Expert System API",
	description="ระบบผู้เชี่ยวชาญประเมินความเสี่ยงโรคเบาหวาน",
	version="1.0.0",
	lifespan=lifespan,
)


app.add_middleware(
	CORSMiddleware,
	allow_origins=["*"],
	allow_credentials=True,
	allow_methods=["*"],
	allow_headers=["*"],
)


app.include_router(assessment_router)


@app.get("/")
def root():
	return {
		"message": "Diabetes Expert System API is running"
	}
