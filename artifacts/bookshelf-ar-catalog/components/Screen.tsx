import { ReactNode } from "react";
import { ScrollView, StyleSheet, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { useColors } from "@/hooks/useColors";

export function Screen({ children, scroll = true }: { children: ReactNode; scroll?: boolean }) {
  const colors = useColors();
  const insets = useSafeAreaInsets();
  const content = (
    <View style={[styles.content, { paddingTop: insets.top + 18, paddingBottom: insets.bottom + 96 }]}>
      {children}
    </View>
  );
  return scroll ? (
    <ScrollView style={{ backgroundColor: colors.background }} showsVerticalScrollIndicator={false}>
      {content}
    </ScrollView>
  ) : (
    <View style={{ flex: 1, backgroundColor: colors.background }}>{content}</View>
  );
}
const styles = StyleSheet.create({ content: { width: "100%", maxWidth: 390, alignSelf: "center", paddingHorizontal: 22, gap: 16 } });