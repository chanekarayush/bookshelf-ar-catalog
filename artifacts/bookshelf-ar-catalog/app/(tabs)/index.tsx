import { Feather } from "@expo/vector-icons";
import { router } from "expo-router";
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from "react-native";
import { Screen } from "@/components/Screen";
import { BookCover } from "@/components/BookCover";
import { useLibrary } from "@/context/LibraryContext";
import { useColors } from "@/hooks/useColors";

export default function Home() {
  const colors = useColors();
  const { books, shelf, hydrated } = useLibrary();
  if (!hydrated) return <View style={[styles.loading, { backgroundColor: colors.background }]}><ActivityIndicator color={colors.primary} /></View>;
  const placed = books.filter((book) => book.placement).length;
  return (
    <Screen>
      <View style={styles.eyebrow}><View style={[styles.dot, { backgroundColor: colors.primary }]} /><Text style={[styles.eyebrowText, { color: colors.mutedForeground }]}>YOUR READING ROOM</Text></View>
      <Text style={[styles.title, { color: colors.foreground }]}>Find your books,{"\n"}without the hunt.</Text>
      <Text style={[styles.subtitle, { color: colors.mutedForeground }]}>A quiet catalog for the books you own and the shelf they call home.</Text>
      <Pressable testID="add-book" onPress={() => router.push("/add-book")} style={({ pressed }) => [styles.primary, { backgroundColor: colors.primary, opacity: pressed ? 0.8 : 1 }]}>
        <Feather name="plus" size={20} color={colors.primaryForeground} /><Text style={[styles.primaryText, { color: colors.primaryForeground }]}>Add a book</Text>
      </Pressable>
      <View style={[styles.shelfCard, { backgroundColor: colors.card, borderColor: colors.border }]}>
        <View style={styles.row}><View style={[styles.shelfIcon, { backgroundColor: colors.accent }]}><Feather name="layers" size={19} color={colors.primary} /></View><View style={styles.flex}><Text style={[styles.cardLabel, { color: colors.mutedForeground }]}>ACTIVE SHELF</Text><Text style={[styles.cardTitle, { color: colors.foreground }]}>{shelf.name}</Text></View><Pressable testID="shelf-settings" onPress={() => router.push("/shelf")}><Feather name="settings" size={19} color={colors.mutedForeground} /></Pressable></View>
        <View style={[styles.progressTrack, { backgroundColor: colors.border }]}><View style={[styles.progress, { width: `${Math.min(100, placed / Math.max(books.length, 1) * 100)}%`, backgroundColor: colors.primary }]} /></View>
        <View style={styles.row}><Text style={[styles.small, { color: colors.mutedForeground }]}>{placed} of {books.length} placed</Text><Pressable onPress={() => router.push("/shelf")}><Text style={[styles.link, { color: colors.primary }]}>{shelf.mapped ? "Re-scan shelf" : "Set up shelf"} <Feather name="arrow-up-right" size={13} /></Text></Pressable></View>
      </View>
      <View style={styles.sectionHead}><Text style={[styles.sectionTitle, { color: colors.foreground }]}>Recently added</Text><Pressable onPress={() => router.push("/catalog")}><Text style={[styles.link, { color: colors.primary }]}>See all</Text></Pressable></View>
      {books.slice(0, 2).map((book) => <Pressable key={book.id} onPress={() => router.push({ pathname: "/book/[id]", params: { id: book.id } })} style={styles.bookRow}><BookCover uri={book.coverUrl} title={book.title} /><View style={styles.flex}><Text style={[styles.bookTitle, { color: colors.foreground }]} numberOfLines={1}>{book.title}</Text><Text style={[styles.bookAuthor, { color: colors.mutedForeground }]} numberOfLines={1}>{book.authors}</Text><Text style={[styles.status, { color: book.placement ? colors.primary : colors.mutedForeground }]}>{book.placement ? "Placed on shelf" : "Needs placement"}</Text></View><Feather name="chevron-right" size={18} color={colors.mutedForeground} /></Pressable>)}
    </Screen>
  );
}
const styles = StyleSheet.create({
  loading: { flex: 1, alignItems: "center", justifyContent: "center" }, eyebrow: { flexDirection: "row", alignItems: "center", gap: 8, marginBottom: 4 }, dot: { width: 8, height: 8, borderRadius: 4 }, eyebrowText: { fontSize: 11, fontWeight: "700", letterSpacing: 1.5 }, title: { fontSize: 34, lineHeight: 39, fontWeight: "700", letterSpacing: -1 }, subtitle: { fontSize: 15, lineHeight: 22, maxWidth: 330 }, primary: { height: 52, borderRadius: 16, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 9, marginTop: 3 }, primaryText: { fontSize: 16, fontWeight: "700" }, shelfCard: { borderWidth: 1, borderRadius: 20, padding: 16, gap: 14, marginTop: 5 }, row: { flexDirection: "row", alignItems: "center", gap: 12 }, shelfIcon: { width: 42, height: 42, borderRadius: 13, alignItems: "center", justifyContent: "center" }, flex: { flex: 1 }, cardLabel: { fontSize: 10, fontWeight: "700", letterSpacing: 1 }, cardTitle: { fontSize: 16, fontWeight: "700", marginTop: 3 }, progressTrack: { height: 6, borderRadius: 4, overflow: "hidden" }, progress: { height: 6, borderRadius: 4 }, small: { fontSize: 12 }, link: { fontSize: 13, fontWeight: "700" }, sectionHead: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginTop: 10 }, sectionTitle: { fontSize: 19, fontWeight: "700" }, bookRow: { flexDirection: "row", alignItems: "center", gap: 14, paddingVertical: 4 }, bookTitle: { fontSize: 15, fontWeight: "700" }, bookAuthor: { fontSize: 13, marginTop: 3 }, status: { fontSize: 12, marginTop: 8, fontWeight: "600" },
});
