import * as Location from "expo-location";
import { Platform } from "react-native";
import type { ShelfLocation } from "@/context/LibraryContext";

export type ShelfLocationResult = {
  location: ShelfLocation | null;
  status: "saved" | "denied" | "unavailable";
};

const LOCATION_TIMEOUT_MS = 6_000;

export async function captureShelfLocation(): Promise<ShelfLocationResult> {
  if (Platform.OS === "web") return { location: null, status: "unavailable" };

  try {
    const permission = await Location.requestForegroundPermissionsAsync();
    if (permission.status !== "granted") return { location: null, status: "denied" };

    const current = await Promise.race([
      Location.getCurrentPositionAsync({
        accuracy: Location.Accuracy.Balanced,
      }),
      new Promise<null>((resolve) => setTimeout(() => resolve(null), LOCATION_TIMEOUT_MS)),
    ]);
    if (!current) return { location: null, status: "unavailable" };
    const { latitude, longitude, accuracy } = current.coords;
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      return { location: null, status: "unavailable" };
    }

    return {
      location: {
        latitude,
        longitude,
        accuracy: typeof accuracy === "number" && Number.isFinite(accuracy) ? accuracy : undefined,
        capturedAt: new Date().toISOString(),
      },
      status: "saved",
    };
  } catch {
    return { location: null, status: "unavailable" };
  }
}

export function distanceInMeters(from: ShelfLocation, to: Pick<ShelfLocation, "latitude" | "longitude">) {
  const earthRadius = 6_371_000;
  const latitudeDelta = toRadians(to.latitude - from.latitude);
  const longitudeDelta = toRadians(to.longitude - from.longitude);
  const latitude1 = toRadians(from.latitude);
  const latitude2 = toRadians(to.latitude);
  const haversine =
    Math.sin(latitudeDelta / 2) ** 2
    + Math.cos(latitude1) * Math.cos(latitude2) * Math.sin(longitudeDelta / 2) ** 2;
  return earthRadius * 2 * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
}

export function isNearShelf(distance: number, savedAccuracy?: number, currentAccuracy?: number) {
  const accuracyAllowance = (savedAccuracy ?? 0) + (currentAccuracy ?? 0);
  return distance <= Math.max(75, accuracyAllowance);
}

export function formatDistance(distance: number) {
  if (distance < 1000) return `${Math.round(distance)} m away`;
  return `${(distance / 1000).toFixed(1)} km away`;
}

function toRadians(value: number) {
  return value * Math.PI / 180;
}