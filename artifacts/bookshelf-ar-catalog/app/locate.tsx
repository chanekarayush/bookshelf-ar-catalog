import { Feather } from "@expo/vector-icons";
import { router, useLocalSearchParams } from "expo-router";
import { useMemo, useState } from "react";
import { ActivityIndicator, Platform, Pressable, StyleSheet, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Screen } from "@/components/Screen";
import { useLibrary } from "@/context/LibraryContext";
import { useColors } from "@/hooks/useColors";
import { BookshelfARView, isNativeARAvailable, type ARTrackingStatus } from "@/modules/bookshelf-ar-native/src";

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
  const placementsJSON = useMemo(
    () => JSON.stringify(books.filter((item) => item.shelfId === bookShelf.id && item.placement).map((item) => ({ id: item.id, ...item.placement }))),
    [books, bookShelf.id],
  );

  if (!hydrated) return <View style={[styles.loading, { backgroundColor: colors.foreground }]}><ActivityIndicator color={colors.primary} /></View>;
  if (!book) return <Screen><Text style={{ color: colors.foreground }}>Book not found.</Text></Screen>;

  const onBookPlaced = async (event: { nativeEvent: { bookId: string; x: number; y: number; z: number } }) => {
    if (event.nativeEvent.bookId !== book.id) return;
    await placeBook(book.id, { x: event.nativeEvent.x, y: event.nativeEvent.y, z: event.nativeEvent.z });
    setStatus("placed");
    setDetail("This position is saved locally with the shelf map.");
  };

  const topInset = Platform.OS === "web" ? Math.max(insets.top, 67) : insets.top;
  const canUseAR = isNativeARAvailable && bookShelf.mapped;
  const statusText = !bookShelf.mapped
    ? "Map this shelf on an iPhone before placing or locating books."
    : detail || statusCopy[status];
  const statusColor = status === "shelf_found" || status === "placed" ? colors.primary : colors.mutedForeground;

  return <View style={[styles.root, { backgroundColor: colors.foreground }]}><View style={[styles.top, { paddingTop: topInset + 12 }]}><Pressable onPress={() => router.back()} style={[styles.icon, { backgroundColor: colors.card }]} accessibilityLabel="Close AR"><Feather name="x" size={22} color={colors.foreground} /></Pressable><View style={[styles.tracking, { backgroundColor: colors.card }]}><View style={[styles.dot, { backgroundColor: statusColor }]} /><Text style={[styles.trackingText, { color: colors.foreground }]}>{detail || statusCopy[status]}</Text></View><View style={styles.iconSpacer} /></View><View style={styles.scene}>{canUseAR ? <BookshelfARView mode={isPlacing ? "place" : "locate"} shelfId={bookShelf.id} selectedBookId={book.id} placementsJSON={placementsJSON} style={StyleSheet.absoluteFill} onTrackingStatusChanged={(event) => { setStatus(event.nativeEvent.status); setDetail(event.nativeEvent.message ?? ""); }} onBookPlaced={onBookPlaced} /> : <View style={[styles.preview, { backgroundColor: colors.secondary, borderColor: colors.border }]}><Feather name={bookShelf.mapped ? "smartphone" : "layers"} size={32} color={colors.primary} /><Text style={[styles.previewTitle, { color: colors.foreground }]}>{bookShelf.mapped ? "Open the native iOS build" : "Map this shelf first"}</Text><Text style={[styles.previewText, { color: colors.mutedForeground }]}>{bookShelf.mapped ? "Expo Go and the web preview cannot load the ARKit bridge. Use the iPhone build to relocalize this shelf." : "Scan and save this shelf on an iPhone before placing or locating books."}</Text>{!bookShelf.mapped && <Pressable onPress={() => router.replace({ pathname: "/shelf", params: { shelfId: bookShelf.id } })} style={[styles.rescan, { backgroundColor: colors.primary }]}><Text style={[styles.rescanText, { color: colors.primaryForeground }]}>Map shelf</Text></Pressable>}</View>}{canUseAR && isPlacing && status !== "unavailable" && <View style={[styles.placementHint, { backgroundColor: colors.card }]}><Feather name="crosshair" size={17} color={colors.primary} /><Text style={[styles.hintText, { color: colors.foreground }]}>Tap the book’s position on the shelf</Text></View>}{canUseAR && status === "unavailable" && <View style={[styles.preview, styles.unavailableOverlay, { backgroundColor: colors.card, borderColor: colors.border }]}><Feather name="alert-circle" size={30} color={colors.primary} /><Text style={[styles.previewTitle, { color: colors.foreground }]}>ARKit is unavailable</Text><Text style={[styles.previewText, { color: colors.mutedForeground }]}>{detail || "Use an iPhone 12 or newer running the custom iOS build to find this shelf."}</Text><Pressable onPress={() => router.back()} style={[styles.rescan, { backgroundColor: colors.primary }]}><Text style={[styles.rescanText, { color: colors.primaryForeground }]}>Back to book</Text></Pressable></View>}{canUseAR && status === "shelf_not_found" && <Pressable onPress={() => router.replace({ pathname: "/shelf", params: { shelfId: bookShelf.id } })} style={[styles.rescan, styles.rescanOverlay, { backgroundColor: colors.primary }]}><Text style={[styles.rescanText, { color: colors.primaryForeground }]}>Re-scan shelf</Text></Pressable>}</View><View style={[styles.bottom, { backgroundColor: colors.background, paddingBottom: insets.bottom + 18 }]}><Text style={[styles.kicker, { color: colors.mutedForeground }]}>{isPlacing ? "PLACE THIS BOOK" : "YOU’RE LOOKING FOR"}</Text><Text style={[styles.bookTitle, { color: colors.foreground }]}>{book.title}</Text><Text style={[styles.author, { color: colors.mutedForeground }]}>{book.authors}</Text><Text style={[styles.note, { color: colors.mutedForeground }]}>{statusText}</Text><Pressable testID="done-locating" onPress={() => router.back()} style={[styles.done, { backgroundColor: colors.primary }]}><Text style={[styles.doneText, { color: colors.primaryForeground }]}>Done</Text></Pressable></View></View>;
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