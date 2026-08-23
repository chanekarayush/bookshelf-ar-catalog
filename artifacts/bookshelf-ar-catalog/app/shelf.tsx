import { Feather } from "@expo/vector-icons";
import { router, useLocalSearchParams } from "expo-router";
import { useState } from "react";
import { Alert, Pressable, StyleSheet, Text, TextInput, View } from "react-native";
import { Screen } from "@/components/Screen";
import {
  BookshelfARView,
  isNativeARAvailable,
  setShelfOrigin,
  type ARTrackingStatus,
} from "@/modules/bookshelf-ar-native/src";
import { useLibrary } from "@/context/LibraryContext";
import { useColors } from "@/hooks/useColors";

const statusCopy: Record<ARTrackingStatus, string> = {
  scanning: "Scanning the shelf…",
  searching: "Searching for the shelf…",
  shelf_found: "Shelf recognized",
  shelf_not_found: "Shelf not found",
  ready_to_place: "Ready to save the shelf origin",
  placed: "Book position saved",
  limited: "Move slowly and keep the shelf in view",
  unavailable: "ARKit is unavailable",
};

export default function ShelfSetup() {
  const colors = useColors();
  const { shelf, shelves, setupShelf } = useLibrary();
  const { shelfId } = useLocalSearchParams<{ shelfId?: string }>();
  const targetShelf = shelves.find((item) => item.id === shelfId) ?? shelf;
  const [name, setName] = useState<string>(targetShelf.name);
  const [status, setStatus] = useState<ARTrackingStatus>("scanning");
  const [detail, setDetail] = useState("Move across the shelf until the map is ready to save.");
  const [saving, setSaving] = useState(false);
  const readyToSave = isNativeARAvailable && status === "ready_to_place";
  const saveLabel = !isNativeARAvailable
    ? "Native iOS build required"
    : status === "unavailable"
      ? "ARKit unavailable"
      : saving
        ? "Saving shelf…"
        : readyToSave
          ? targetShelf.mapped ? "Replace shelf map" : "Set shelf origin"
          : "Scanning shelf…";

  const save = async () => {
    if (!name.trim()) {
      Alert.alert("Name your shelf", "Give this bookcase level a name.");
      return;
    }
    if (!isNativeARAvailable) {
      Alert.alert(
        "iPhone AR build required",
        "This feature needs the custom iOS build. Expo Go and the web preview cannot run the ARKit world-map bridge.",
      );
      return;
    }

    setSaving(true);
    try {
      const result = await setShelfOrigin(targetShelf.id);
      if (!result.saved || !result.mapId) {
        Alert.alert(
          "Shelf not saved",
          result.reason === "tracking-not-ready"
            ? "Move slowly until ARKit says the shelf scan is ready, then try again."
            : "Keep the bookcase in view and try scanning again.",
        );
        return;
      }
      await setupShelf(targetShelf.id, name.trim(), result.mapId);
      Alert.alert("Shelf saved", "The shelf map is stored locally on this iPhone.", [
        { text: "Done", onPress: () => router.back() },
      ]);
    } finally {
      setSaving(false);
    }
  };
  const requestSave = () => {
    if (!targetShelf.mapped) {
      void save();
      return;
    }
    Alert.alert(
      "Replace shelf map?",
      "Replacing this shelf map clears all saved book positions because they are tied to the current shelf origin.",
      [
        { text: "Cancel", style: "cancel" },
        { text: "Replace and clear positions", style: "destructive", onPress: () => void save() },
      ],
    );
  };

  return (
    <Screen>
      <View style={styles.top}>
        <Pressable onPress={() => router.back()} accessibilityLabel="Go back">
          <Feather name="arrow-left" size={22} color={colors.foreground} />
        </Pressable>
        <Text style={[styles.topTitle, { color: colors.foreground }]}>Shelf setup</Text>
        <View style={styles.topSpacer} />
      </View>

      <View style={[styles.hero, { backgroundColor: colors.accent }]}>
        <Feather name="layers" size={38} color={colors.primary} />
        <Text style={[styles.heroTitle, { color: colors.foreground }]}>
          {targetShelf.mapped ? "Re-scan your shelf" : "Map your bookcase level"}
        </Text>
        <Text style={[styles.heroText, { color: colors.mutedForeground }]}>
          Pan across the full level in even light. The saved world map lets ARKit find this shelf after relaunch.
        </Text>
      </View>

      {isNativeARAvailable ? (
        <View style={[styles.cameraFrame, { borderColor: colors.border, backgroundColor: colors.foreground }]}>
          <BookshelfARView
            mode="scan"
            shelfId={targetShelf.id}
            style={styles.camera}
            onTrackingStatusChanged={(event) => {
              setStatus(event.nativeEvent.status);
              setDetail(event.nativeEvent.message ?? statusCopy[event.nativeEvent.status]);
            }}
          />
          <View style={[styles.statusBadge, { backgroundColor: colors.card }]}>
            <View style={[styles.statusDot, { backgroundColor: readyToSave ? colors.primary : colors.mutedForeground }]} />
            <Text style={[styles.statusText, { color: colors.foreground }]}>{detail}</Text>
          </View>
        </View>
      ) : (
        <View style={[styles.nativeNotice, { backgroundColor: colors.secondary, borderColor: colors.border }]}>
          <Feather name="smartphone" size={26} color={colors.primary} />
          <View style={styles.noticeText}>
            <Text style={[styles.noticeTitle, { color: colors.foreground }]}>Native iOS build required</Text>
            <Text style={[styles.noticeBody, { color: colors.mutedForeground }]}>
              Build the app for an iPhone 12 or newer to scan and save a real ARKit world map.
            </Text>
          </View>
        </View>
      )}

      <Text style={[styles.label, { color: colors.mutedForeground }]}>SHELF NAME</Text>
      <TextInput
        value={name}
        onChangeText={setName}
        placeholder="Living room bookcase"
        placeholderTextColor={colors.mutedForeground}
        style={[styles.input, { color: colors.foreground, borderColor: colors.border, backgroundColor: colors.card }]}
      />
      <View style={[styles.steps, { borderColor: colors.border }]}>
        <Step n="1" text="Pan slowly across the bookcase" colors={colors} />
        <Step n="2" text="Wait for the scan to be ready" colors={colors} />
        <Step n="3" text="Save the shelf origin" colors={colors} />
      </View>
      {readyToSave ? (
        <Pressable
          testID="set-shelf-origin"
          disabled={saving}
          onPress={requestSave}
          style={[styles.button, { backgroundColor: colors.primary, opacity: saving ? 0.65 : 1 }]}
        >
          <Feather name="crosshair" size={18} color={colors.primaryForeground} />
          <Text style={[styles.buttonText, { color: colors.primaryForeground }]}>{saveLabel}</Text>
        </Pressable>
      ) : (
        <View
          testID="set-shelf-origin-disabled"
          accessibilityRole="button"
          accessibilityState={{ disabled: true }}
          style={[styles.button, styles.disabledButton, { backgroundColor: colors.secondary, borderColor: colors.border }]}
        >
          <Feather name={!isNativeARAvailable || status === "unavailable" ? "lock" : "loader"} size={18} color={colors.mutedForeground} />
          <Text style={[styles.buttonText, { color: colors.mutedForeground }]}>{saveLabel}</Text>
        </View>
      )}
    </Screen>
  );
}

function Step({ n, text, colors }: { n: string; text: string; colors: ReturnType<typeof useColors> }) {
  return (
    <View style={styles.step}>
      <View style={[styles.number, { backgroundColor: colors.primary }]}>
        <Text style={{ color: colors.primaryForeground, fontWeight: "700" }}>{n}</Text>
      </View>
      <Text style={[styles.stepText, { color: colors.foreground }]}>{text}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  top: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  topTitle: { fontSize: 15, fontWeight: "700" },
  topSpacer: { width: 22 },
  hero: { borderRadius: 22, padding: 24, alignItems: "center", gap: 12, marginTop: 16 },
  heroTitle: { fontSize: 21, fontWeight: "700", textAlign: "center" },
  heroText: { fontSize: 14, lineHeight: 21, textAlign: "center" },
  cameraFrame: { height: 250, overflow: "hidden", borderRadius: 20, borderWidth: 1 },
  camera: { flex: 1 },
  statusBadge: {
    position: "absolute",
    left: 12,
    right: 12,
    bottom: 12,
    borderRadius: 14,
    paddingHorizontal: 12,
    paddingVertical: 10,
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  statusDot: { width: 8, height: 8, borderRadius: 4 },
  statusText: { fontSize: 13, fontWeight: "700" },
  nativeNotice: {
    borderWidth: 1,
    borderRadius: 18,
    padding: 16,
    flexDirection: "row",
    gap: 12,
    alignItems: "center",
  },
  noticeText: { flex: 1, gap: 3 },
  noticeTitle: { fontSize: 14, fontWeight: "700" },
  noticeBody: { fontSize: 13, lineHeight: 19 },
  label: { fontSize: 11, fontWeight: "700", letterSpacing: 1.3, marginTop: 8 },
  input: { height: 50, borderWidth: 1, borderRadius: 14, paddingHorizontal: 14, fontSize: 15 },
  steps: { borderWidth: 1, borderRadius: 17, padding: 16, gap: 16 },
  step: { flexDirection: "row", alignItems: "center", gap: 12 },
  number: { width: 28, height: 28, borderRadius: 14, alignItems: "center", justifyContent: "center" },
  stepText: { fontSize: 14 },
  button: { height: 52, borderRadius: 16, alignItems: "center", justifyContent: "center", flexDirection: "row", gap: 9 },
  disabledButton: { borderWidth: 1 },
  buttonText: { fontSize: 16, fontWeight: "700" },
});