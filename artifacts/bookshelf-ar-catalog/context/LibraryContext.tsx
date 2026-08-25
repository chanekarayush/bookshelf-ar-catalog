import AsyncStorage from "@react-native-async-storage/async-storage";
import React, { createContext, useContext, useEffect, useMemo, useRef, useState } from "react";

export type Placement = { x: number; y: number; z: number };
export type ShelfLocation = {
  latitude: number;
  longitude: number;
  accuracy?: number;
  capturedAt: string;
};
export type Book = {
  id: string;
  isbn: string;
  title: string;
  authors: string;
  publisher: string;
  subjects: string;
  description: string;
  coverUrl?: string;
  shelfId?: string;
  placement?: Placement;
  updatedAt: string;
};
export type Shelf = {
  id: string;
  name: string;
  mapped: boolean;
  worldMapId?: string;
  lastMappedAt?: string;
  location?: ShelfLocation;
};

type LibraryValue = {
  books: Book[];
  shelves: Shelf[];
  shelf: Shelf;
  hydrated: boolean;
  saveBook: (book: Omit<Book, "id" | "updatedAt"> & { id?: string }) => Promise<Book>;
  placeBook: (id: string, placement: Placement) => Promise<void>;
  assignBookToShelf: (bookId: string, shelfId: string) => Promise<void>;
  createShelf: (name: string, bookId?: string) => Promise<Shelf>;
  setupShelf: (shelfId: string, name: string, worldMapId: string, location?: ShelfLocation | null) => Promise<void>;
  setShelfLocation: (shelfId: string, worldMapId: string, location: ShelfLocation) => Promise<void>;
};

const KEY = "bookshelf-ar-catalog:v1";
const DEFAULT_SHELF: Shelf = { id: "shelf-default", name: "Living room bookcase", mapped: false };
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
    shelfId: DEFAULT_SHELF.id,
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
    shelfId: DEFAULT_SHELF.id,
    updatedAt: new Date().toISOString(),
  },
];

const LibraryContext = createContext<LibraryValue | null>(null);
const id = () => `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

function isValidIsbn13(value: string) {
  if (!/^\d{13}$/.test(value)) return false;
  const sum = value
    .slice(0, 12)
    .split("")
    .reduce((total, digit, index) => total + Number(digit) * (index % 2 === 0 ? 1 : 3), 0);
  return (10 - (sum % 10)) % 10 === Number(value[12]);
}

function isbn13CheckDigit(firstTwelveDigits: string) {
  const sum = firstTwelveDigits
    .split("")
    .reduce((total, digit, index) => total + Number(digit) * (index % 2 === 0 ? 1 : 3), 0);
  return String((10 - (sum % 10)) % 10);
}

export function canonicalizeIsbn(value: string) {
  const isbn = value.replace(/[-\s]/g, "").toUpperCase();
  if (isValidIsbn13(isbn)) return isbn;
  if (!/^\d{9}[\dX]$/.test(isbn)) return null;
  const checksum = isbn
    .split("")
    .reduce((total, character, index) => total + (character === "X" ? 10 : Number(character)) * (10 - index), 0);
  if (checksum % 11 !== 0) return null;
  const prefix = `978${isbn.slice(0, 9)}`;
  return `${prefix}${isbn13CheckDigit(prefix)}`;
}

export function LibraryProvider({ children }: { children: React.ReactNode }) {
  const [books, setBooks] = useState<Book[]>([]);
  const [shelves, setShelves] = useState<Shelf[]>([DEFAULT_SHELF]);
  const [activeShelfId, setActiveShelfId] = useState(DEFAULT_SHELF.id);
  const [hydrated, setHydrated] = useState(false);
  const booksRef = useRef<Book[]>([]);
  const shelvesRef = useRef<Shelf[]>([DEFAULT_SHELF]);

  useEffect(() => {
    AsyncStorage.getItem(KEY)
      .then((raw) => {
        if (!raw) {
          setBooks(demoBooks);
          booksRef.current = demoBooks;
          return;
        }
        const saved = JSON.parse(raw) as { books?: Book[]; shelf?: Omit<Shelf, "id"> & { id?: string }; shelves?: Shelf[]; activeShelfId?: string };
        const legacyShelf: Shelf = saved.shelf
          ? { ...saved.shelf, id: saved.shelf.id ?? DEFAULT_SHELF.id }
          : DEFAULT_SHELF;
        const nextShelves = saved.shelves?.length ? saved.shelves : [legacyShelf];
        const defaultShelfId = nextShelves[0].id;
        const nextBooks = (saved.books ?? []).map((book) => ({ ...book, shelfId: book.shelfId ?? defaultShelfId }));
        setBooks(nextBooks);
        setShelves(nextShelves);
        booksRef.current = nextBooks;
        shelvesRef.current = nextShelves;
        setActiveShelfId(saved.activeShelfId ?? defaultShelfId);
      })
      .catch(() => {
        setBooks(demoBooks);
        booksRef.current = demoBooks;
      })
      .finally(() => setHydrated(true));
  }, []);

  const shelf = shelves.find((item) => item.id === activeShelfId) ?? shelves[0] ?? DEFAULT_SHELF;
  const persist = async (nextBooks: Book[], nextShelves: Shelf[], nextActiveShelfId = activeShelfId) => {
    await AsyncStorage.setItem(KEY, JSON.stringify({
      books: nextBooks,
      shelves: nextShelves,
      activeShelfId: nextActiveShelfId,
      shelf: nextShelves.find((item) => item.id === nextActiveShelfId) ?? nextShelves[0] ?? DEFAULT_SHELF,
    }));
  };

  const saveBook = async (input: Omit<Book, "id" | "updatedAt"> & { id?: string }) => {
    const isbn = canonicalizeIsbn(input.isbn);
    if (!isbn) throw new Error("A valid ISBN-10 or ISBN-13 is required.");
    const matchingIsbn = books.find((book) => canonicalizeIsbn(book.isbn) === isbn);
    const existing = matchingIsbn ?? books.find((book) => book.id === input.id);
    const next: Book = {
      ...input,
      isbn,
      id: existing?.id ?? input.id ?? id(),
      shelfId: input.shelfId ?? existing?.shelfId,
      placement: input.placement ?? existing?.placement,
      updatedAt: new Date().toISOString(),
    };
    const nextBooks = books.some((book) => book.id === next.id)
      ? books.map((book) => (book.id === next.id ? next : book))
      : [next, ...books];
    setBooks(nextBooks);
    booksRef.current = nextBooks;
    await persist(nextBooks, shelves);
    return next;
  };

  const placeBook = async (bookId: string, placement: Placement) => {
    const nextBooks = books.map((book) => book.id === bookId ? { ...book, placement, updatedAt: new Date().toISOString() } : book);
    setBooks(nextBooks);
    booksRef.current = nextBooks;
    await persist(nextBooks, shelves);
  };

  const assignBookToShelf = async (bookId: string, shelfId: string) => {
    const nextBooks = books.map((book) => book.id === bookId ? { ...book, shelfId, placement: undefined, updatedAt: new Date().toISOString() } : book);
    setBooks(nextBooks);
    booksRef.current = nextBooks;
    setActiveShelfId(shelfId);
    await persist(nextBooks, shelves, shelfId);
  };

  const createShelf = async (name: string, bookId?: string) => {
    const nextShelf: Shelf = { id: id(), name, mapped: false };
    const nextShelves = [...shelves, nextShelf];
    const nextBooks = bookId
      ? books.map((book) => book.id === bookId ? { ...book, shelfId: nextShelf.id, placement: undefined, updatedAt: new Date().toISOString() } : book)
      : books;
    setShelves(nextShelves);
    setBooks(nextBooks);
    shelvesRef.current = nextShelves;
    booksRef.current = nextBooks;
    setActiveShelfId(nextShelf.id);
    await persist(nextBooks, nextShelves, nextShelf.id);
    return nextShelf;
  };

  const setupShelf = async (shelfId: string, name: string, worldMapId: string, location?: ShelfLocation | null) => {
    const targetShelf = shelves.find((item) => item.id === shelfId) ?? shelf;
    const nextShelf: Shelf = {
      ...targetShelf,
      name,
      mapped: true,
      worldMapId,
      lastMappedAt: new Date().toISOString(),
      ...(location === undefined ? {} : { location: location ?? undefined }),
    };
    const nextShelves = shelves.map((item) => item.id === targetShelf.id ? nextShelf : item);
    const nextBooks = targetShelf.mapped && targetShelf.worldMapId !== worldMapId
      ? books.map((book) => book.shelfId === targetShelf.id ? { ...book, placement: undefined, updatedAt: new Date().toISOString() } : book)
      : books;
    setBooks(nextBooks);
    setShelves(nextShelves);
    booksRef.current = nextBooks;
    shelvesRef.current = nextShelves;
    setActiveShelfId(targetShelf.id);
    await persist(nextBooks, nextShelves, targetShelf.id);
  };

  const setShelfLocation = async (shelfId: string, worldMapId: string, location: ShelfLocation) => {
    let updated = false;
    const nextShelves = shelvesRef.current.map((item) => {
      if (item.id !== shelfId || item.worldMapId !== worldMapId) return item;
      updated = true;
      return { ...item, location };
    });
    if (!updated) return;
    shelvesRef.current = nextShelves;
    setShelves(nextShelves);
    await persist(booksRef.current, nextShelves, shelfId);
  };

  const value = useMemo(
    () => ({ books, shelves, shelf, hydrated, saveBook, placeBook, assignBookToShelf, createShelf, setupShelf, setShelfLocation }),
    [books, shelves, shelf, hydrated],
  );
  return <LibraryContext.Provider value={value}>{children}</LibraryContext.Provider>;
}

export function useLibrary() {
  const value = useContext(LibraryContext);
  if (!value) throw new Error("useLibrary must be used inside LibraryProvider");
  return value;
}