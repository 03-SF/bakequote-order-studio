import chocolate from "@/assets/cake-chocolate.jpg";
import cupcakes from "@/assets/cupcakes.jpg";
import floral from "@/assets/bakery-hero.jpg";
import type { ImageKey } from "./types";

export const IMAGES: Record<ImageKey, string> = { chocolate, cupcakes, floral };

/** Local-only demo upload: downsizes the image and returns a data URL kept in browser storage. */
export function fileToDataUrl(file: File, max = 720): Promise<string> {
  return new Promise((resolve, reject) => {
    if (!file.type.startsWith("image/")) return reject(new Error("Please choose an image file."));
    if (file.size > 10 * 1024 * 1024) return reject(new Error("Image is over 10 MB."));
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      const scale = Math.min(1, max / Math.max(img.width, img.height));
      const c = document.createElement("canvas");
      c.width = Math.round(img.width * scale);
      c.height = Math.round(img.height * scale);
      c.getContext("2d")!.drawImage(img, 0, 0, c.width, c.height);
      URL.revokeObjectURL(url);
      resolve(c.toDataURL("image/jpeg", 0.72));
    };
    img.onerror = () => reject(new Error("Couldn't read that image."));
    img.src = url;
  });
}
