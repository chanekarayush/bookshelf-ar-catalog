import { requireNativeModule, requireNativeViewManager } from "expo-modules-core";
import { createElement, type ComponentType } from "react";
import { Platform, type StyleProp, type ViewStyle } from "react-native";

export type ARTrackingStatus =
  | "scanning"
  | "searching"
  | "shelf_found"
  | "shelf_not_found"
  | "ready_to_place"
  | "placed"
  | "limited"
  | "unavailable";

export type ARTrackingEvent = {
  status: ARTrackingStatus;
  message?: string;
};

export type ARBookPlacedEvent = {
  bookId: string;
  x: number;
  y: number;
  z: number;
};

export type BookshelfARViewProps = {
  mode: "scan" | "locate" | "place";
  shelfId: string;
  selectedBookId?: string;
  placementsJSON?: string;
  style?: StyleProp<ViewStyle>;
  onTrackingStatusChanged?: (event: { nativeEvent: ARTrackingEvent }) => void;
  onBookPlaced?: (event: { nativeEvent: ARBookPlacedEvent }) => void;
};

export type BookshelfARModule = {
  setShelfOrigin: (shelfId: string) => Promise<{
    saved: boolean;
    mapId?: string;
    savedAt?: string;
    reason?: string;
  }>;
  clearWorldMap: (shelfId: string) => Promise<{ cleared: boolean }>;
};

let nativeModule: BookshelfARModule | null = null;
let nativeView: ComponentType<BookshelfARViewProps> | null = null;

if (Platform.OS === "ios") {
  try {
    nativeModule = requireNativeModule<BookshelfARModule>("BookshelfAR");
    nativeView = requireNativeViewManager<BookshelfARViewProps>("BookshelfAR");
  } catch {
    // Expo Go and web do not contain the custom ARKit module. The screens
    // render an explicit native-build message in this case.
  }
}

export const isNativeARAvailable = nativeModule !== null && nativeView !== null;

export function BookshelfARView(props: BookshelfARViewProps) {
  if (!nativeView) return null;
  const NativeView = nativeView;
  return createElement(NativeView, props);
}

export async function setShelfOrigin(shelfId: string) {
  if (!nativeModule) return { saved: false, reason: "native-module-unavailable" };
  return nativeModule.setShelfOrigin(shelfId);
}

export async function clearWorldMap(shelfId: string) {
  if (!nativeModule) return { cleared: false };
  return nativeModule.clearWorldMap(shelfId);
}