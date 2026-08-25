import { Feather } from "@expo/vector-icons";
import { router, useLocalSearchParams } from "expo-router";
import { useEffect, useMemo, useState } from "react";
import { ActivityIndicator, Platform, Pressable, StyleSheet, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Screen } from "@/components/Screen";
import { useLibrary } from "@/context/LibraryContext";
import { useColors } from "@/hooks/useColors";
import { BookshelfARView, isNativeARAvailable, type ARTrackingStatus } from "@/modules/bookshelf-ar-native/src";
import { captureShelfLocation, distanceInMeters, formatDistance, isNearShelf } from "@/utils/location";

const statusCopy: Record<ARTrackingStatus, string> = {
  scanning: "Scanning the shelf…",
  searching: "Searching for the saved shelf…",
  shelf_found: "Shelf found",
  shelf_not_found: "Shelf cannot be found",
  ready_to_place: "Ready to save the shelf origin",
  placed: "Book position saved",
  limited: "Move slowly and keep the shelf in view",
  unavailable: "ARKit is unavailable",
};

type GpsState = "ready" | "checking" | "near" | "far" | "not_saved" | "denied" | "unavailable";

export default function Locate() {
  const colors = useColors();
  const insets = useSafeAreaInsets();
  const { id, placing } = useLocalSearchParams<{ id: string; placing?: string }>();
  const { books, shelves, shelf, hydrated, placeBook } = useLibrary();
  const book = books.find((item) => item.id === id);
  const bookShelf = book?.shelfId ? shelves.find((item) => item.id === book.shelfId) ?? shelf : shelf;
  const isPlacing = placing === "true" || !book?.placement;
  const [status, setStatus] = useState<ARTrackingStatus>("searching");
  const [detail, setDetail] = useState("");
  const [gpsState, setGpsState] = useState<GpsState>("ready");
  const [gpsDistance, setGpsDistance] = useState<number>();
  const [arStarted, setArStarted] = useState(false);
  const placementsJSON = useMemo(
    () => JSON.stringify(books.filter((item) => item.shelfId === bookShelf.id && item.placement).map((item) => ({ id: item.id, ...item.placement }))),
    [books, bookShelf.id],
  );

  useEffect(() => {
    if (!hydrated || !book) return;
    if (!bookShelf.location) {
      setGpsState("not_saved");
      setArStarted(true);
      return;
    }
    setGpsState("ready");
    setGpsDistance(undefined);
  }, [book, bookShelf.id, bookShelf.location, hydrated]);

  if (!hydrated) return <View style={[styles.loading, { backgroundColor: colors.foreground }]}><ActivityIndicator color={colors.primary} /></View>;
  if (!book) return <Screen><Text style={{ color: colors.foreground }}>Book not found.</Text></Screen>;

  const onBookPlaced = async (event: { nativeEvent: { bookId: string; x: number; y: number; z: number } }) => {
    if (event.nativeEvent.bookId !== book.id) return;
    await placeBook(book.id, { x: event.nativeEvent.x, y: event.nativeEvent.y, z: event.nativeEvent.z });
    setStatus("placed");
    setDetail("This position is saved locally with the shelf map.");
  };
  const checkShelfArea = async () => {
    if (!bookShelf.location) {
      setArStarted(true);
      return;
    }
    setGpsState("checking");
    const result = await captureShelfLocation();
    if (result.status === "denied") {
      setGpsState("denied");
      setArStarted(true);
      return;
    }
    if (!result.location) {
      setGpsState("unavailable");
      setArStarted(true);
      return;
    }
    const distance = distanceInMeters(bookShelf.location, result.location);
    setGpsDistance(distance);
    setGpsState(isNearShelf(distance, bookShelf.location.accuracy, result.location.accuracy) ? "near" : "far");
  };

  const topInset = Platform.OS === "web" ? Math.max(insets.top, 67) : insets.top;
  const canUseAR = isNativeARAvailable && bookShelf.mapped;
  const statusText = !bookShelf.mapped
    ? "Map this shelf on an iPhone before placing or locating books."
    : gpsState === "denied"
      ? "GPS permission was denied. AR can still locate this shelf."
      : gpsState === "unavailable"
        ? "GPS is unavailable. AR can still locate this shelf."
        : gpsState === "not_saved"
          ? "No GPS area was saved. AR will try to locate this shelf directly."
          : gpsState === "near" && gpsDistance !== undefined
            ? `GPS says you are ${formatDistance(gpsDistance)} from this shelf.`
    : detail || statusCopy[status];
  const statusColor = status === "shelf_found" || status === "placed" ? colors.primary : colors.mutedForeground;
  const gpsGateTitle = gpsState === "ready"
    ? "Check your shelf area"
    : gpsState === "checking"
      ? "Checking your shelf area"
      : gpsState === "near"
        ? "You’re near this shelf"
        : "This shelf is farther away";
  const gpsGateText = gpsState === "ready"
    ? "Use GPS to confirm the right room or area before opening AR. You can skip this step."
    : gpsState === "checking"
      ? "Waiting briefly for a GPS reading. You can open AR at any time."
    : gpsState === "near" && gpsDistance !== undefined
      ? `${formatDistance(gpsDistance)} based on your saved shelf area.`
      : gpsDistance !== undefined
        ? `${formatDistance(gpsDistance)} based on your saved shelf area. You can still open AR here.`
        : "Location access is needed for this room-level check.";

  return (
    <View style={[styles.root, { backgroundColor: colors.foreground }]}>
      <View style={[styles.top, { paddingTop: topInset + 12 }]}>
        <Pressable onPress={() => router.back()} style={[styles.icon, { backgroundColor: colors.card }]} accessibilityLabel="Close AR">
          <Feather name="x" size={22} color={colors.foreground} />
        </Pressable>
        <View style={[styles.tracking, { backgroundColor: colors.card }]}>
          <View style={[styles.dot, { backgroundColor: statusColor }]} />
          <Text style={[styles.trackingText, { color: colors.foreground }]}>
            {arStarted ? detail || statusCopy[status] : gpsState === "checking" ? "Checking GPS…" : gpsState === "near" ? "Shelf area confirmed" : "Check shelf area"}
          </Text>
        </View>
        <View style={styles.iconSpacer} />
      </View>

      <View style={styles.scene}>
        {!arStarted ? (
          <View style={[styles.gpsGate, { backgroundColor: colors.card, borderColor: colors.border }]}>
            <Feather name={gpsState === "checking" ? "map-pin" : "navigation"} size={34} color={colors.primary} />
            <Text style={[styles.gpsGateTitle, { color: colors.foreground }]}>{gpsGateTitle}</Text>
            <Text style={[styles.gpsGateText, { color: colors.mutedForeground }]}>{gpsGateText}</Text>
            {gpsState === "ready" && (
              <Pressable testID="check-shelf-gps" onPress={() => void checkShelfArea()} style={[styles.gpsAction, { backgroundColor: colors.primary }]}>
                <Text style={[styles.gpsActionText, { color: colors.primaryForeground }]}>Check shelf area</Text>
              </Pressable>
            )}
            <Pressable
              testID="open-ar-locator"
              onPress={() => setArStarted(true)}
              style={[styles.gpsAction, gpsState === "ready" ? styles.gpsSecondaryAction : undefined, { backgroundColor: gpsState === "ready" ? colors.secondary : colors.primary, borderColor: colors.border }]}
            >
              <Text style={[styles.gpsActionText, { color: gpsState === "ready" ? colors.foreground : colors.primaryForeground }]}>
                {gpsState === "checking" ? "Skip GPS and open AR" : gpsState === "ready" ? "Open AR without GPS" : "Open AR locator"}
              </Text>
            </Pressable>
          </View>
        ) : (
          <>
            {canUseAR ? (
              <BookshelfARView
                mode={isPlacing ? "place" : "locate"}
                shelfId={bookShelf.id}
                selectedBookId={book.id}
                placementsJSON={placementsJSON}
                style={StyleSheet.absoluteFill}
                onTrackingStatusChanged={(event) => {
                  setStatus(event.nativeEvent.status);
                  setDetail(event.nativeEvent.message ?? "");
                }}
                onBookPlaced={onBookPlaced}
              />
            ) : (
              <View style={[styles.preview, { backgroundColor: colors.secondary, borderColor: colors.border }]}>
                <Feather name={bookShelf.mapped ? "smartphone" : "layers"} size={32} color={colors.primary} />
                <Text style={[styles.previewTitle, { color: colors.foreground }]}>
                  {bookShelf.mapped ? "Open the native iOS build" : "Map this shelf first"}
                </Text>
                <Text style={[styles.previewText, { color: colors.mutedForeground }]}>
                  {bookShelf.mapped
                    ? "Expo Go and the web preview cannot load the ARKit bridge. Use the iPhone build to relocalize this shelf."
                    : "Scan and save this shelf on an iPhone before placing or locating books."}
                </Text>
                {!bookShelf.mapped && (
                  <Pressable onPress={() => router.replace({ pathname: "/shelf", params: { shelfId: bookShelf.id } })} style={[styles.rescan, { backgroundColor: colors.primary }]}>
                    <Text style={[styles.rescanText, { color: colors.primaryForeground }]}>Map shelf</Text>
                  </Pressable>
                )}
              </View>
            )}
            {canUseAR && isPlacing && status !== "unavailable" && (
              <View style={[styles.placementHint, { backgroundColor: colors.card }]}>
                <Feather name="crosshair" size={17} color={colors.primary} />
                <Text style={[styles.hintText, { color: colors.foreground }]}>Tap the book’s position on the shelf</Text>
              </View>
            )}
            {canUseAR && status === "unavailable" && (
              <View style={[styles.preview, styles.unavailableOverlay, { backgroundColor: colors.card, borderColor: colors.border }]}>
                <Feather name="alert-circle" size={30} color={colors.primary} />
                <Text style={[styles.previewTitle, { color: colors.foreground }]}>ARKit is unavailable</Text>
                <Text style={[styles.previewText, { color: colors.mutedForeground }]}>
                  {detail || "Use an iPhone 12 or newer running the custom iOS build to find this shelf."}
                </Text>
                <Pressable onPress={() => router.back()} style={[styles.rescan, { backgroundColor: colors.primary }]}>
                  <Text style={[styles.rescanText, { color: colors.primaryForeground }]}>Back to book</Text>
                </Pressable>
              </View>
            )}
            {canUseAR && status === "shelf_not_found" && (
              <Pressable onPress={() => router.replace({ pathname: "/shelf", params: { shelfId: bookShelf.id } })} style={[styles.rescan, styles.rescanOverlay, { backgroundColor: colors.primary }]}>
                <Text style={[styles.rescanText, { color: colors.primaryForeground }]}>Re-scan shelf</Text>
              </Pressable>
            )}
          </>
        )}
      </View>

      <View style={[styles.bottom, { backgroundColor: colors.background, paddingBottom: insets.bottom + 18 }]}>
        <Text style={[styles.kicker, { color: colors.mutedForeground }]}>{isPlacing ? "PLACE THIS BOOK" : "YOU’RE LOOKING FOR"}</Text>
        <Text style={[styles.bookTitle, { color: colors.foreground }]}>{book.title}</Text>
        <Text style={[styles.author, { color: colors.mutedForeground }]}>{book.authors}</Text>
        <Text style={[styles.note, { color: colors.mutedForeground }]}>{statusText}</Text>
        <Pressable testID="done-locating" onPress={() => router.back()} style={[styles.done, { backgroundColor: colors.primary }]}>
          <Text style={[styles.doneText, { color: colors.primaryForeground }]}>Done</Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  loading: { flex: 1, alignItems: "center", justifyContent: "center" },
  top: { paddingHorizontal: 20, flexDirection: "row", justifyContent: "space-between", alignItems: "center", zIndex: 2 },
  icon: { width: 40, height: 40, borderRadius: 20, alignItems: "center", justifyContent: "center" },
  iconSpacer: { width: 40 },
  tracking: { flexDirection: "row", alignItems: "center", gap: 7, paddingHorizontal: 12, paddingVertical: 8, borderRadius: 20 },
  dot: { width: 7, height: 7, borderRadius: 4 },
  trackingText: { fontSize: 12, fontWeight: "700" },
  scene: { flex: 1, marginTop: 12, alignItems: "center", justifyContent: "center" },
  gpsGate: { marginHorizontal: 22, borderWidth: 1, borderRadius: 22, padding: 24, alignItems: "center", gap: 10 },
  gpsGateTitle: { fontSize: 20, fontWeight: "700", textAlign: "center" },
  gpsGateText: { fontSize: 14, lineHeight: 20, textAlign: "center" },
  gpsAction: { borderRadius: 14, paddingHorizontal: 18, paddingVertical: 12, marginTop: 4 },
  gpsSecondaryAction: { borderWidth: 1 },
  gpsActionText: { fontSize: 14, fontWeight: "700" },
  preview: { marginHorizontal: 22, borderWidth: 1, borderRadius: 22, padding: 24, alignItems: "center", gap: 10 },
  unavailableOverlay: { position: "absolute", left: 0, right: 0, alignSelf: "center" },
  previewTitle: { fontSize: 18, fontWeight: "700", textAlign: "center" },
  previewText: { fontSize: 14, lineHeight: 20, textAlign: "center" },
  placementHint: { position: "absolute", top: 18, borderRadius: 16, paddingHorizontal: 14, paddingVertical: 10, flexDirection: "row", alignItems: "center", gap: 8 },
  hintText: { fontSize: 13, fontWeight: "700" },
  rescan: { alignSelf: "center", borderRadius: 14, paddingHorizontal: 16, paddingVertical: 11, marginTop: 4 },
  rescanOverlay: { position: "absolute", bottom: 22 },
  rescanText: { fontSize: 14, fontWeight: "700" },
  bottom: { borderTopLeftRadius: 28, borderTopRightRadius: 28, paddingHorizontal: 24, paddingTop: 22, gap: 8 },
  kicker: { fontSize: 10, fontWeight: "700", letterSpacing: 1.5 },
  bookTitle: { fontSize: 23, fontWeight: "700", marginTop: 3 },
  author: { fontSize: 14 },
  note: { fontSize: 13, lineHeight: 19, marginTop: 8 },
  done: { height: 49, borderRadius: 15, alignItems: "center", justifyContent: "center", marginTop: 10 },
  doneText: { fontSize: 16, fontWeight: "700" },
});