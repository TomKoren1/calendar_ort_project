import { Router } from "express";
import * as userController from "../controllers/userController.js";
import asyncHandler from "../utils/asyncHandler.js";

const router = Router();

router.get("/", asyncHandler(userController.list));
router.get("/:id", asyncHandler(userController.getOne));
router.post("/", asyncHandler(userController.create));
router.put("/:id", asyncHandler(userController.update));
router.delete("/:id", asyncHandler(userController.remove));

export default router;
