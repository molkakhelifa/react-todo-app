import { render } from "@testing-library/react";
import { test, expect } from "vitest";
import TodoList from "./ToDoList";

test("renders without crashing", () => {
  render(<TodoList />);
  expect(true).toBe(true);
});
