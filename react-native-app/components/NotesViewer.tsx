import React from "react";
import { StyleSheet, View, Text } from "react-native";
import Markdown from "react-native-markdown-display";

interface NotesViewerProps {
  markdown: string;
}

// Custom styles that highlight ✱ sections (content missed while distracted)
const markdownStyles = StyleSheet.create({
  body: {
    fontSize: 14,
    lineHeight: 22,
    color: "#333",
  },
  heading1: {
    fontSize: 22,
    fontWeight: "bold",
    color: "#002147",
    marginBottom: 8,
    marginTop: 12,
    borderBottomWidth: 2,
    borderBottomColor: "#C9A84C",
    paddingBottom: 4,
  },
  heading2: {
    fontSize: 18,
    fontWeight: "bold",
    color: "#002147",
    marginBottom: 6,
    marginTop: 10,
  },
  heading3: {
    fontSize: 15,
    fontWeight: "600",
    color: "#002147",
    marginBottom: 4,
    marginTop: 8,
  },
  strong: {
    fontWeight: "bold",
    color: "#002147",
  },
  bullet_list_icon: {
    color: "#C9A84C",
    marginTop: 6,
  },
  ordered_list_icon: {
    color: "#002147",
    marginTop: 6,
  },
  code_block: {
    backgroundColor: "#f5f5f5",
    borderRadius: 4,
    padding: 8,
    fontFamily: "monospace",
    fontSize: 12,
  },
  code_inline: {
    backgroundColor: "#f5f5f5",
    fontFamily: "monospace",
    fontSize: 12,
    borderRadius: 3,
  },
  blockquote: {
    borderLeftWidth: 4,
    borderLeftColor: "#C9A84C",
    paddingLeft: 12,
    marginLeft: 0,
    backgroundColor: "#fffdf0",
  },
  paragraph: {
    marginBottom: 8,
  },
});

/**
 * NotesViewer — renders markdown lecture notes.
 * Lines starting with ✱ get a highlighted background to mark
 * content the student missed while distracted (CLAUDE.md §12.3).
 */
export default function NotesViewer({ markdown }: NotesViewerProps) {
  // Pre-process: wrap ✱ lines in a blockquote for visual highlight
  const processed = markdown
    .split("\n")
    .map((line) =>
      line.trimStart().startsWith("✱") ? `> ${line}` : line
    )
    .join("\n");

  return (
    <View style={styles.container}>
      <Markdown style={markdownStyles}>{processed}</Markdown>
      <View style={styles.legend}>
        <Text style={styles.legendDot}>▶</Text>
        <Text style={styles.legendText}>
          Highlighted sections = content taught while you were distracted
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  legend: {
    flexDirection: "row",
    alignItems: "flex-start",
    backgroundColor: "#fff9e6",
    padding: 10,
    borderTopWidth: 1,
    borderTopColor: "#ffe0b2",
    marginTop: 8,
    borderRadius: 4,
  },
  legendDot: {
    color: "#C9A84C",
    marginRight: 6,
    fontSize: 12,
  },
  legendText: {
    fontSize: 11,
    color: "#f57f17",
    fontStyle: "italic",
    flex: 1,
  },
});
