import { Router } from "express";
import * as calendarController from "../controllers/calendarController.js";
import asyncHandler from "../utils/asyncHandler.js";

const router = Router();

router.get("/", asyncHandler(calendarController.list));
router.get("/:id", asyncHandler(calendarController.getOne));
router.post("/", asyncHandler(calendarController.create));
router.put("/:id", asyncHandler(calendarController.update));
router.delete("/:id", asyncHandler(calendarController.remove));

export default router;
