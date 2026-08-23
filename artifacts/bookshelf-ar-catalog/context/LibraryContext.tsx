import AsyncStorage from "@react-native-async-storage/async-storage";
import React, { createContext, useContext, useEffect, useMemo, useState } from "react";

export type Placement = { x: number; y: number; z: number };
export type Book = {
  id: string;
  isbn: string;
  title: string;
  authors: string;
  publisher: string;
  subjects: string;
  description: string;
  coverUrl?: string;
  placement?: Placement;
  updatedAt: string;
};
export type Shelf = { name: string; mapped: boolean; lastMappedAt?: string };
type LibraryValue = {
  books: Book[];
  shelf: Shelf;
  hydrated: boolean;
  saveBook: (book: Omit<Book, "id" | "updatedAt"> & { id?: string }) => Promise<Book>;
  placeBook: (id: string, placement?: Placement) => Promise<void>;
  setupShelf: (name: string) => Promise<void>;
};

const KEY = "bookshelf-ar-catalog:v1";
const demoBooks: Book[] = [
  {
    id: "demo-1",
    isbn: "9780140328721",
    title: "Fantastic Mr Fox",
    authors: "Roald Dahl",
    publisher: "Penguin",
    subjects: "Children, Fiction",
    description: "A quick-witted fox outsmarts three farmers.",
    coverUrl: "https://covers.openlibrary.org/b/isbn/9780140328721-M.jpg",
    placement: { x: 0.35, y: 0.12, z: 0 },
    updatedAt: new Date().toISOString(),
  },
  {
    id: "demo-2",
    isbn: "9780140449136",
    title: "The Odyssey",
    authors: "Homer",
    publisher: "Penguin Classics",
    subjects: "Classics, Poetry",
    description: "Odysseus journeys home after the Trojan War.",
    coverUrl: "https://covers.openlibrary.org/b/isbn/9780140449136-M.jpg",
    placement: { x: 0.68, y: 0.1, z: 0 },
    updatedAt: new Date().toISOString(),
  },
];

const LibraryContext = createContext<LibraryValue | null>(null);
const id = () => `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

export function LibraryProvider({ children }: { children: React.ReactNode }) {
  const [books, setBooks] = useState<Book[]>([]);
  const [shelf, setShelf] = useState<Shelf>({ name: "Living room bookcase", mapped: false });
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    AsyncStorage.getItem(KEY)
      .then((raw) => {
        if (!raw) return setBooks(demoBooks);
        const saved = JSON.parse(raw) as { books?: Book[]; shelf?: Shelf };
        setBooks(saved.books ?? []);
        setShelf(saved.shelf ?? { name: "Living room bookcase", mapped: false });
      })
      .catch(() => setBooks(demoBooks))
      .finally(() => setHydrated(true));
  }, []);

  const persist = async (nextBooks: Book[], nextShelf: Shelf) => {
    await AsyncStorage.setItem(KEY, JSON.stringify({ books: nextBooks, shelf: nextShelf }));
  };
  const saveBook = async (input: Omit<Book, "id" | "updatedAt"> & { id?: string }) => {
    const next = { ...input, id: input.id ?? id(), updatedAt: new Date().toISOString() };
    const nextBooks = books.some((book) => book.id === next.id)
      ? books.map((book) => (book.id === next.id ? next : book))
      : [next, ...books];
    setBooks(nextBooks);
    await persist(nextBooks, shelf);
    return next;
  };
  const placeBook = async (bookId: string, placement: Placement = { x: 0.5, y: 0.14, z: 0 }) => {
    const nextBooks = books.map((book) =>
      book.id === bookId ? { ...book, placement, updatedAt: new Date().toISOString() } : book,
    );
    setBooks(nextBooks);
    await persist(nextBooks, shelf);
  };
  const setupShelf = async (name: string) => {
    const nextShelf = { name, mapped: true, lastMappedAt: new Date().toISOString() };
    setShelf(nextShelf);
    await persist(books, nextShelf);
  };
  const value = useMemo(
    () => ({ books, shelf, hydrated, saveBook, placeBook, setupShelf }),
    [books, shelf, hydrated],
  );
  return <LibraryContext.Provider value={value}>{children}</LibraryContext.Provider>;
}

export function useLibrary() {
  const value = useContext(LibraryContext);
  if (!value) throw new Error("useLibrary must be used inside LibraryProvider");
  return value;
}