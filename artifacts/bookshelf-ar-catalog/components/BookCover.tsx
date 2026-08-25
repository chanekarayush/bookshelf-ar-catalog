import { Image, StyleSheet, Text, View } from "react-native";
import { useColors } from "@/hooks/useColors";

export function BookCover({ uri, title, size = 70 }: { uri?: string; title: string; size?: number }) {
  const colors = useColors();
  return uri ? (
    <Image source={{ uri }} style={[styles.cover, { width: size * 0.68, height: size }]} />
  ) : (
    <View style={[styles.cover, styles.fallback, { width: size * 0.68, height: size, backgroundColor: colors.accent }]}>
      <Text style={[styles.initial, { color: colors.primary }]}>{title.charAt(0)}</Text>
    </View>
  );
}
const styles = StyleSheet.create({
  cover: { borderRadius: 7, backgroundColor: "#e9e1d4" },
  fallback: { alignItems: "center", justifyContent: "center" },
  initial: { fontSize: 28, fontWeight: "700" },
});