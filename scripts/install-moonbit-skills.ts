#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";
import readline from "node:readline";

const REPO_URL = "https://github.com/moonbitlang/skills.git";
const CLONE_DIR = "moonbit-skills";
const SKILLS_SRC_REL = path.join(CLONE_DIR, "skills");

const PRESET_DIRS = [
  ".claude",
  ".zcode",
  ".trae",
].map(v => path.join(v, 'skills'));

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

function question(prompt: string): Promise<string> {
  return new Promise(resolve => rl.question(prompt, resolve));
}

function runGitClone() {
  console.log("==> Cloning moonbit skills repository...");

  if (fs.existsSync(CLONE_DIR)) {
    console.log(`Directory '${CLONE_DIR}' already exists, removing...`);
    fs.rmSync(CLONE_DIR, { recursive: true, force: true });
  }

  execSync(`git clone ${REPO_URL} ${CLONE_DIR}`, { stdio: "inherit" });
}

function copySkills(targetDir: string) {
  const absTarget = path.resolve(process.cwd(), targetDir);
  const absSource = path.resolve(process.cwd(), SKILLS_SRC_REL);

  if (!fs.existsSync(absSource)) {
    throw new Error(`Source directory not found: ${absSource}`);
  }

  fs.mkdirSync(absTarget, { recursive: true });
  fs.cpSync(absSource, absTarget, { recursive: true });

  console.log(`✔ Skills copied to: ${targetDir}`);
}

async function main() {
  try {
    runGitClone();

    // 遍历SKILLS_SRC_REL下的所有文件夹，删除PRESET_DIRS下的同名文件夹
    for(const name in fs.readdirSync(SKILLS_SRC_REL)) {
      const paths = PRESET_DIRS.map(dir => path.join(dir, name));
      for (const p of paths) {
        if (fs.existsSync(p)) {
        console.log(`Removing existing directory: ${p}`);
        fs.rmSync(p, { recursive: true, force: true });
      }
      }
    }

    // 复制技能到预设目录
    for (const dir of PRESET_DIRS) {
      console.log(`==> Copying skills to preset directory: ${dir}`);
      copySkills(dir);
    }


    const customChoice = await question(
      "\nDo you want to copy skills to a custom directory? (y/n): "
    );

    if (customChoice.toLowerCase() === "y") {
      const customDir = (await question(
        "Enter the custom directory path (relative to current dir): "
      )).trim();

      if (!customDir) {
        console.log("No directory entered, skipping.");
      } else {
        console.log(`==> Copying skills to custom directory: ${customDir}`);
        copySkills(customDir);
      }
    }

    console.log("\n==> Done.");
  } catch (err) {
    console.error("❌ Error:", err);
    process.exit(1);
  } finally {
    rl.close();
    // 删除克隆文件夹
    if (fs.existsSync(CLONE_DIR)) {
      fs.rmSync(CLONE_DIR, { recursive: true, force: true });
    }
  }
}

main();