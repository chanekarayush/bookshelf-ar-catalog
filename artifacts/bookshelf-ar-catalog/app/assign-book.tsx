import { Feather } from "@expo/vector-icons";
import { router, useLocalSearchParams } from "expo-router";
import { useState } from "react";
import { ActivityIndicator, Pressable, StyleSheet, Text, TextInput, View } from "react-native";
import { Screen } from "@/components/Screen";
import { useLibrary } from "@/context/LibraryContext";
import { useColors } from "@/hooks/useColors";

export default function AssignBook() {
  const colors = useColors();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { books, shelves, hydrated, assignBookToShelf, createShelf } = useLibrary();
  const [adding, setAdding] = useState(false);
  const [name, setName] = useState("");
  const book = books.find((item) => item.id === id);

  if (!hydrated) {
    return <View style={[styles.loading, { backgroundColor: colors.background }]}><ActivityIndicator color={colors.primary} /></View>;
  }
  if (!book) {
    return <Screen><Text style={{ color: colors.foreground }}>Book not found.</Text></Screen>;
  }

  const openBook = () => router.replace({ pathname: "/book/[id]", params: { id: book.id } });
  const assign = async (shelfId: string) => {
    await assignBookToShelf(book.id, shelfId);
    openBook();
  };
  const addBookcase = async () => {
    const trimmed = name.trim();
    if (!trimmed) return;
    await createShelf(trimmed, book.id);
    openBook();
  };

  return (
    <Screen>
      <View style={styles.top}>
        <Pressable testID="assign-back" onPress={() => router.back()}><Feather name="arrow-left" size={22} color={colors.foreground} /></Pressable>
        <Text style={[styles.topTitle, { color: colors.foreground }]}>Bookcase</Text>
        <View style={{ width: 22 }} />
      </View>
      <Text style={[styles.title, { color: colors.foreground }]}>Where should it live?</Text>
      <Text style={[styles.subtitle, { color: colors.mutedForeground }]}>Choose a bookcase for {book.title}, or leave it unassigned for now.</Text>

      <Text style={[styles.sectionLabel, { color: colors.mutedForeground }]}>YOUR BOOKCASES</Text>
      <View style={styles.list}>
        {shelves.map((item) => (
          <Pressable key={item.id} testID={`assign-bookcase-${item.id}`} onPress={() => assign(item.id)} style={[styles.option, { backgroundColor: colors.card, borderColor: colors.border }]}>
            <View style={[styles.optionIcon, { backgroundColor: colors.accent }]}><Feather name="layers" size={19} color={colors.primary} /></View>
            <View style={styles.flex}><Text style={[styles.optionTitle, { color: colors.foreground }]}>{item.name}</Text><Text style={[styles.optionHint, { color: colors.mutedForeground }]}>{item.mapped ? "Mapped and ready to locate books" : "Not mapped yet"}</Text></View>
            <Feather name="chevron-right" size={18} color={colors.mutedForeground} />
          </Pressable>
        ))}
      </View>

      {adding ? (
        <View style={[styles.newCard, { backgroundColor: colors.accent, borderColor: colors.primary }]}>
          <Text style={[styles.newTitle, { color: colors.foreground }]}>Add a new bookcase</Text>
          <TextInput testID="bookcase-name" autoFocus value={name} onChangeText={setName} placeholder="e.g. Study bookcase" placeholderTextColor={colors.mutedForeground} style={[styles.input, { color: colors.foreground, borderColor: colors.border, backgroundColor: colors.card }]} />
          <View style={styles.actions}>
            <Pressable onPress={() => { setAdding(false); setName(""); }} style={styles.cancel}><Text style={[styles.cancelText, { color: colors.mutedForeground }]}>Cancel</Text></Pressable>
            <Pressable testID="confirm-new-bookcase" disabled={!name.trim()} onPress={addBookcase} style={[styles.confirm, { backgroundColor: colors.primary, opacity: name.trim() ? 1 : .5 }]}><Text style={[styles.confirmText, { color: colors.primaryForeground }]}>Add bookcase</Text></Pressable>
          </View>
        </View>
      ) : (
        <Pressable testID="add-bookcase" onPress={() => setAdding(true)} style={[styles.add, { borderColor: colors.primary, backgroundColor: colors.accent }]}>
          <View style={[styles.addIcon, { backgroundColor: colors.primary }]}><Feather name="plus" size={17} color={colors.primaryForeground} /></View>
          <View style={styles.flex}><Text style={[styles.addTitle, { color: colors.foreground }]}>Add a new bookcase</Text><Text style={[styles.optionHint, { color: colors.mutedForeground }]}>Create a place for this and future books</Text></View>
          <Feather name="chevron-right" size={18} color={colors.primary} />
        </Pressable>
      )}

      <Pressable testID="skip-assignment" onPress={openBook} style={styles.skip}><Text style={[styles.skipText, { color: colors.mutedForeground }]}>Skip for now</Text></Pressable>
    </Screen>
  );
}

const styles = StyleSheet.create({
  loading: { flex: 1, alignItems: "center", justifyContent: "center" },
  top: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  topTitle: { fontSize: 15, fontWeight: "700" },
  title: { fontSize: 31, fontWeight: "700", letterSpacing: -.7, marginTop: 16 },
  subtitle: { fontSize: 15, lineHeight: 22, marginTop: -7 },
  sectionLabel: { fontSize: 11, fontWeight: "700", letterSpacing: 1.3, marginTop: 18 },
  list: { gap: 10 },
  option: { minHeight: 72, borderWidth: 1, borderRadius: 17, padding: 13, flexDirection: "row", alignItems: "center", gap: 12 },
  optionIcon: { width: 40, height: 40, borderRadius: 12, alignItems: "center", justifyContent: "center" },
  flex: { flex: 1 },
  optionTitle: { fontSize: 15, fontWeight: "700" },
  optionHint: { fontSize: 12, marginTop: 3 },
  newCard: { borderWidth: 1, borderRadius: 18, padding: 14, gap: 10 },
  newTitle: { fontSize: 15, fontWeight: "700" },
  input: { height: 47, borderWidth: 1, borderRadius: 13, paddingHorizontal: 13, fontSize: 15 },
  actions: { flexDirection: "row", justifyContent: "flex-end", alignItems: "center", gap: 16 },
  cancel: { paddingVertical: 10 },
  cancelText: { fontSize: 14, fontWeight: "600" },
  confirm: { borderRadius: 12, paddingHorizontal: 15, paddingVertical: 11 },
  confirmText: { fontSize: 14, fontWeight: "700" },
  add: { minHeight: 72, borderWidth: 1, borderRadius: 17, padding: 13, flexDirection: "row", alignItems: "center", gap: 12, marginTop: 2 },
  addIcon: { width: 40, height: 40, borderRadius: 12, alignItems: "center", justifyContent: "center" },
  addTitle: { fontSize: 15, fontWeight: "700" },
  skip: { alignItems: "center", paddingVertical: 13 },
  skipText: { fontSize: 14, fontWeight: "600" },
});