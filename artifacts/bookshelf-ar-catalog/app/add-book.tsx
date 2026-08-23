import { CameraView, useCameraPermissions } from "expo-camera";
import { Feather } from "@expo/vector-icons";
import { router } from "expo-router";
import { useState } from "react";
import { Alert, Keyboard, Pressable, StyleSheet, Text, TextInput, View } from "react-native";
import { Screen } from "@/components/Screen";
import { useLibrary } from "@/context/LibraryContext";
import { useColors } from "@/hooks/useColors";

const normalize = (value: string) => value.replace(/[-\s]/g, "");
type Form = { isbn: string; title: string; authors: string; publisher: string; subjects: string; description: string; coverUrl: string };

export default function AddBook() {
  const colors = useColors(); const { books, shelf, saveBook, placeBook } = useLibrary();
  const [permission, requestPermission] = useCameraPermissions(); const [scanning, setScanning] = useState(false); const [loading, setLoading] = useState(false);
  const [form, setForm] = useState<Form>({ isbn: "", title: "", authors: "", publisher: "", subjects: "", description: "", coverUrl: "" });
  const set = (key: keyof Form, value: string) => setForm((old) => ({ ...old, [key]: value }));
  const lookup = async (isbn: string) => {
    setLoading(true);
    try {
      const response = await fetch(`https://openlibrary.org/isbn/${isbn}.json`);
      if (!response.ok) throw new Error("not found");
      const data = await response.json();
      const authors = (data.authors ?? []).map((author: { name?: string }) => author.name).filter(Boolean).join(", ");
      setForm((old) => ({ ...old, title: data.title ?? "", authors, publisher: data.publishers?.[0] ?? "", subjects: (data.subjects ?? []).slice(0, 4).join(", "), coverUrl: `https://covers.openlibrary.org/b/isbn/${isbn}-M.jpg` }));
    } catch { Alert.alert("Book not found", "Enter the book details manually before saving."); }
    finally { setLoading(false); }
  };
  const onBarcode = ({ data }: { data: string }) => { const isbn = normalize(data); if (!/^\d{10}(\d{3})?$/.test(isbn)) return; setScanning(false); set("isbn", isbn); lookup(isbn); };
  const save = async () => {
    Keyboard.dismiss(); const isbn = normalize(form.isbn);
    if (!/^\d{10}(\d{3})?$/.test(isbn) || !form.title.trim() || !form.authors.trim()) return Alert.alert("Almost there", "ISBN, title, and author are required.");
    const existing = books.find((book) => book.isbn === isbn);
    const book = await saveBook({ ...form, isbn, title: form.title.trim(), authors: form.authors.trim(), id: existing?.id });
    if (shelf.mapped) { await placeBook(book.id); router.replace({ pathname: "/locate", params: { id: book.id, placing: "true" } }); } else router.replace({ pathname: "/book/[id]", params: { id: book.id } });
  };
  if (scanning) return <View style={styles.camera}><CameraView style={StyleSheet.absoluteFill} facing="back" barcodeScannerSettings={{ barcodeTypes: ["ean13", "ean8"] }} onBarcodeScanned={onBarcode} /><View style={styles.cameraShade}><Pressable onPress={() => setScanning(false)} style={styles.close}><Feather name="x" size={23} color="#fff" /></Pressable><View style={styles.scanBox}><View style={styles.corner} /></View><Text style={styles.cameraText}>Line up the barcode inside the frame</Text></View></View>;
  return <Screen><View style={styles.top}><Pressable onPress={() => router.back()}><Feather name="arrow-left" size={22} color={colors.foreground} /></Pressable><Text style={[styles.topTitle, { color: colors.foreground }]}>Add a book</Text><View style={{ width: 22 }} /></View><Text style={[styles.title, { color: colors.foreground }]}>Start with the ISBN.</Text><Text style={[styles.sub, { color: colors.mutedForeground }]}>We’ll find the details, then you can make them yours.</Text><Pressable testID="scan-isbn" onPress={async () => { if (!permission?.granted) { const result = await requestPermission(); if (!result.granted) return Alert.alert("Camera access needed", "Allow camera access in Settings to scan ISBNs."); } setScanning(true); }} style={[styles.scan, { borderColor: colors.primary, backgroundColor: colors.accent }]}><Feather name="maximize" size={21} color={colors.primary} /><View><Text style={[styles.scanTitle, { color: colors.foreground }]}>Scan ISBN barcode</Text><Text style={[styles.scanHint, { color: colors.mutedForeground }]}>On-device camera scan</Text></View><Feather name="chevron-right" size={18} color={colors.primary} /></Pressable><View style={styles.or}><View style={[styles.line, { backgroundColor: colors.border }]} /><Text style={[styles.orText, { color: colors.mutedForeground }]}>or enter manually</Text><View style={[styles.line, { backgroundColor: colors.border }]} /></View><Field label="ISBN" value={form.isbn} onChangeText={(value) => set("isbn", value)} placeholder="978-0-00-000000-0" colors={colors} keyboardType="number-pad" onBlur={() => { if (form.isbn) lookup(normalize(form.isbn)); }} /><Field label="Title" value={form.title} onChangeText={(value) => set("title", value)} placeholder="Book title" colors={colors} /><Field label="Author" value={form.authors} onChangeText={(value) => set("authors", value)} placeholder="Author name" colors={colors} /><Field label="Publisher / year" value={form.publisher} onChangeText={(value) => set("publisher", value)} placeholder="Optional" colors={colors} /><Field label="Subjects" value={form.subjects} onChangeText={(value) => set("subjects", value)} placeholder="Optional, comma separated" colors={colors} /><Pressable disabled={loading} onPress={save} style={[styles.save, { backgroundColor: colors.primary, opacity: loading ? .6 : 1 }]}><Text style={[styles.saveText, { color: colors.primaryForeground }]}>{loading ? "Looking up…" : "Save book"}</Text></Pressable></Screen>;
}
function Field({ label, value, onChangeText, placeholder, colors, keyboardType, onBlur }: { label: string; value: string; onChangeText: (value: string) => void; placeholder: string; colors: ReturnType<typeof useColors>; keyboardType?: "number-pad"; onBlur?: () => void }) { return <View style={fieldStyles.wrap}><Text style={[fieldStyles.label, { color: colors.mutedForeground }]}>{label}</Text><TextInput value={value} onChangeText={onChangeText} onBlur={onBlur} keyboardType={keyboardType} placeholder={placeholder} placeholderTextColor={colors.mutedForeground} style={[fieldStyles.input, { borderColor: colors.border, color: colors.foreground, backgroundColor: colors.card }]} /></View>; }
const styles = StyleSheet.create({ top: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" }, topTitle: { fontSize: 15, fontWeight: "700" }, title: { fontSize: 31, fontWeight: "700", letterSpacing: -.7, marginTop: 16 }, sub: { fontSize: 15, lineHeight: 22, marginTop: -7 }, scan: { borderWidth: 1, borderRadius: 16, padding: 15, flexDirection: "row", alignItems: "center", gap: 12, marginTop: 5 }, scanTitle: { fontSize: 15, fontWeight: "700" }, scanHint: { fontSize: 12, marginTop: 3 }, or: { flexDirection: "row", alignItems: "center", gap: 9, marginVertical: 3 }, line: { height: 1, flex: 1 }, orText: { fontSize: 11 }, save: { height: 52, borderRadius: 16, justifyContent: "center", alignItems: "center", marginTop: 4 }, saveText: { fontSize: 16, fontWeight: "700" }, camera: { flex: 1, backgroundColor: "#07151a" }, cameraShade: { ...StyleSheet.absoluteFillObject, alignItems: "center", justifyContent: "center", backgroundColor: "rgba(0,0,0,.25)" }, close: { position: "absolute", top: 60, right: 22, padding: 10 }, scanBox: { width: 275, height: 155, borderWidth: 2, borderColor: "#f0b56b", borderRadius: 18 }, corner: { width: 40, height: 40, borderTopWidth: 5, borderLeftWidth: 5, borderColor: "#fff", borderTopLeftRadius: 15 }, cameraText: { color: "#fff", fontSize: 15, marginTop: 24, fontWeight: "600" } });
const fieldStyles = StyleSheet.create({ wrap: { gap: 6 }, label: { fontSize: 12, fontWeight: "700" }, input: { borderWidth: 1, height: 48, borderRadius: 13, paddingHorizontal: 14, fontSize: 15 } });