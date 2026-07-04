import { Router } from "express";
import * as tagController from "../controllers/tagController.js";
import asyncHandler from "../utils/asyncHandler.js";

const router = Router();

router.get("/", asyncHandler(tagController.list));
router.get("/:id", asyncHandler(tagController.getOne));
router.post("/", asyncHandler(tagController.create));
router.put("/:id", asyncHandler(tagController.update));
router.delete("/:id", asyncHandler(tagController.remove));

export default router;
