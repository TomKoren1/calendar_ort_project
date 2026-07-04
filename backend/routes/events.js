import { Router } from "express";
import * as eventController from "../controllers/eventController.js";
import asyncHandler from "../utils/asyncHandler.js";

const router = Router();

router.get("/", asyncHandler(eventController.list));
router.get("/:id", asyncHandler(eventController.getOne));
router.post("/", asyncHandler(eventController.create));
router.put("/:id", asyncHandler(eventController.update));
router.delete("/:id", asyncHandler(eventController.remove));

export default router;
