from src.todo import TodoList


def test_add_and_list():
    todos = TodoList()
    todos.add("Buy milk")
    todos.add("Walk dog")
    assert todos.list() == ["Buy milk", "Walk dog"]


def test_remove():
    todos = TodoList()
    todos.add("Keep this")
    todos.add("Remove this")
    removed = todos.remove(1)
    assert removed == "Remove this"
    assert todos.list() == ["Keep this"]
