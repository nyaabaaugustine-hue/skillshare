"""Writes the Academy handouts that the LMS hub offers as downloads.

Usage (from the project root):
    pip install fpdf2
    python tool/make_handouts.py

Writes four PDFs into assets/handouts/, which pubspec.yaml bundles into the app
so the Resources tab can hand the learner a real file on every platform (the
web build saves it through the browser, Android/iOS through the file system).

The content mirrors python_kickstart (lib/features/course/python_course_content.dart)
so a handout and the lesson it comes from say the same thing.

Everything is ASCII: the PDFs use the core Helvetica and Courier fonts, which
are latin-1 only, so accented characters and typographic quotes are stripped by
_ascii() rather than silently dropped or mangled by the encoder.
"""

import os
import sys

from fpdf import FPDF

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "handouts")

INK = (23, 37, 63)
MUTED = (90, 105, 130)
ACCENT = (18, 112, 168)
CODE_BG = (240, 244, 250)


def _ascii(text):
    """Folds the text to ASCII, keeping the core-font PDF encoding safe."""
    replacements = {
        "\u2014": "-",
        "\u2013": "-",
        "\u2018": "'",
        "\u2019": "'",
        "\u201c": '"',
        "\u201d": '"',
        "\u2026": "...",
        "\u00a0": " ",
    }
    for src, dst in replacements.items():
        text = text.replace(src, dst)
    return text.encode("ascii", "replace").decode("ascii")


class Handout(FPDF):
    """A PDF with the Academy header rule and page numbers."""

    def __init__(self, title):
        super().__init__(orientation="P", unit="mm", format="A4")
        self.doc_title = _ascii(title)
        self.set_auto_page_break(auto=True, margin=20)
        self.set_margins(18, 16, 18)
        self.set_title(self.doc_title)
        self.set_author("SkillBridge Academy")

    def header(self):
        self.set_font("Helvetica", "B", 8.5)
        self.set_text_color(*ACCENT)
        self.cell(0, 5, "SKILLBRIDGE ACADEMY", new_x="LMARGIN", new_y="NEXT")
        self.set_draw_color(*CODE_BG)
        self.set_line_width(0.6)
        y = self.get_y() + 1
        self.line(self.l_margin, y, self.w - self.r_margin, y)
        self.set_y(y + 6)
        self.set_text_color(*INK)

    def footer(self):
        self.set_y(-14)
        self.set_font("Helvetica", "", 8.5)
        self.set_text_color(*MUTED)
        self.cell(0, 5, _ascii(f"{self.doc_title}  |  page {self.page_no()}"), align="C")


def _write(pdf, height, text, **kwargs):
    """Writes a block that wraps, always returning the cursor to the margin."""
    pdf.multi_cell(
        0, height, _ascii(text), new_x="LMARGIN", new_y="NEXT", **kwargs
    )


def title(pdf, text):
    pdf.set_font("Helvetica", "B", 20)
    pdf.set_text_color(*INK)
    _write(pdf, 9, text)
    pdf.ln(2)


def intro(pdf, text):
    pdf.set_font("Helvetica", "", 11.5)
    pdf.set_text_color(*MUTED)
    _write(pdf, 6, text)
    pdf.ln(3)
    pdf.set_text_color(*INK)


def heading(pdf, text):
    pdf.ln(3)
    pdf.set_font("Helvetica", "B", 13)
    pdf.set_text_color(*ACCENT)
    _write(pdf, 7, text)
    pdf.set_text_color(*INK)
    pdf.ln(1)


def body(pdf, text):
    pdf.set_font("Helvetica", "", 11)
    _write(pdf, 5.8, text)
    pdf.ln(1)


def bullets(pdf, items):
    pdf.set_font("Helvetica", "", 11)
    for item in items:
        _write(pdf, 5.8, f"  -  {item}")


def code(pdf, lines):
    pdf.set_font("Courier", "", 9.5)
    pdf.set_fill_color(*CODE_BG)
    for line in lines:
        _write(pdf, 5.2, f"  {line}", fill=True)
    pdf.ln(2)
    pdf.set_text_color(*INK)


CHEAT_SHEET = [
    ("t", "Python Basics Cheat Sheet"),
    (
        "i",
        "Syntax, data types and the operations you reach for most often. Keep "
        "this next to you while you work through the Python Kickstart course.",
    ),
    ("h", "Hello, World!"),
    ("b", "print() sends text to the screen. Text goes in quotes, numbers do not."),
    ("c", ['print("Hello, World!")', "print(7 * 6)          # 42"]),
    ("h", "Types of data"),
    (
        "u",
        [
            "str - text, in quotes: \"Ada\"",
            "int - whole numbers: 12",
            "float - numbers with a decimal point: 3.5",
            "bool - True or False",
            "list - an ordered collection: [1, 2, 3]",
            "dict - key/value pairs: {\"name\": \"Ada\"}",
        ],
    ),
    ("b", "type(x) tells you what something is, and str() / int() / float() convert between types."),
    ("c", ["type(\"12\")     # <class 'str'>", "int(\"12\") + 1  # 13", "str(12) + \" pm\"  # '12 pm'"]),
    ("h", "Variables"),
    ("b", "A variable is a name for a value. Use = to store, and a clear name to keep your code readable."),
    ("c", ["name = \"Ada\"", "score = 10", "score = score + 5", "print(f\"{name} has {score} points\")"]),
    ("h", "Operators"),
    (
        "u",
        [
            "+ - * /   add, subtract, multiply, divide (always a float)",
            "//        integer division: 7 // 2 is 3",
            "%         remainder: 7 % 2 is 1",
            "**        power: 2 ** 3 is 8",
            "== != < > <= >=   comparisons, which evaluate to True or False",
            "and or not       combine conditions",
        ],
    ),
    ("h", "Making decisions"),
    ("c", ["if score >= 50:", "    print(\"Pass\")", "elif score >= 40:", "    print(\"Almost\")", "else:", "    print(\"Try again\")"]),
    ("b", "Python cares about indentation: the indented lines belong to the line above."),
    ("h", "Repeating things"),
    ("c", ["for i in range(3):", "    print(i)        # 0, 1, 2", "", "fruits = [\"mango\", \"banana\"]", "for fruit in fruits:", "    print(fruit.upper())"]),
    ("b", "A while loop repeats as long as its condition stays True. Make sure something inside changes, or it never ends."),
    ("c", ["count = 3", "while count > 0:", "    print(count)", "    count = count - 1"]),
    ("h", "Reading input"),
    ("c", ["name = input(\"Your name? \")", "age = int(input(\"Your age? \"))   # input() always returns text"]),
    ("h", "Working with text"),
    ("u", ["len(text) - how many characters", "text.upper() / text.lower() - change the case", "text.strip() - remove spaces at the ends", "text.split(\",\") - break into a list", "\", \".join(items) - glue a list back into text", "f\"Hello {name}\" - build a string from values"]),
    ("h", "Lists"),
    ("c", ["scores = [3, 9, 5]", "scores.append(7)      # add to the end", "scores[0]             # 3, lists start at 0", "sorted(scores)        # [3, 5, 7, 9]", "len(scores)           # 4"]),
    ("h", "Fixing errors"),
    ("u", ["IndentationError - a line is not indented the way the one above it is", "NameError - you used a name that does not exist yet (often a typo)", "TypeError - mixed types, e.g. \"total: \" + 5; convert with str(5)", "SyntaxError - a missing colon, bracket or quote"]),
    ("b", "Read the last line of the traceback first: it names the error, and the line above points at your code."),
    ("h", "Where to go next"),
    ("b", "Open the Practice tab in the app, work through the challenges, then come back here when you need a reminder."),
]

SLIDES = [
    ("t", "Course Slides - Demystifying Python"),
    (
        "i",
        "The slides behind the Python Kickstart sessions, collected into one "
        "document so you can revisit them without replaying the videos.",
    ),
    ("h", "1. Advancing your career with Python"),
    ("b", "Python is the most common first language because it reads like English and is used across data, web, automation and finance. The goal of this course is not to memorise syntax: it is to be able to make a computer do a small useful job for you."),
    ("h", "2. Why Python over Java"),
    ("u", ["Less ceremony: no class or main method to print one line of text", "Runs immediately, so feedback is fast while you are learning", "Java asks you to declare types up front; Python infers them", "Both are in demand, and knowing either makes the other easier"]),
    ("h", "3. Setting up your environment"),
    ("u", ["Python 3 is what you want; version 2 is out of use", "An editor with syntax highlighting gives you free error checking", "In this app you need nothing installed: the Practice tab runs real Python for you", "Check with: python --version"]),
    ("h", "4. How a program runs"),
    ("b", "Python reads your file from top to bottom and runs each line in order. That single rule explains most surprises: if a variable is used before the line that creates it, the program stops."),
    ("h", "5. Types and variables"),
    ("u", ["A value has a type; a variable is just a name pointing at a value", "Types can change as the program runs - Python is dynamically typed", "Use clear names. total_price beats t every time"]),
    ("h", "6. Strings"),
    ("b", "Text is a string, and strings are sequences: you can count, slice and join them. F-strings interpolate values into text, which is the clearest way to build a message."),
    ("c", ["first = \"Skill\"", "second = \"Bridge\"", "print(f\"{first}{second} Academy\")"]),
    ("h", "7. Collections"),
    ("u", ["list - ordered, changeable, allows duplicates", "dict - look things up by key", "tuple - ordered, cannot be changed after creation", "set - unordered, no duplicates"]),
    ("h", "8. Control flow"),
    ("b", "if chooses between paths; for and while repeat work. Indentation is part of the language, not decoration, so the editor's automatic indentation is doing real work."),
    ("h", "9. Functions"),
    ("c", ["def greet(name):", "    \"\"\"Return a greeting for name.\"\"\"", "    return f\"Hello, {name}!\"", "", "print(greet(\"Ada\"))"]),
    ("u", ["def gives the function a name; the parentheses take the inputs", "return hands a value back to whoever called it", "Small functions that do one thing are easier to test and reuse"]),
    ("h", "10. Handling mistakes"),
    ("b", "Errors are information, not failure. A traceback is read bottom-up: the last line names the problem, the lines above show the path your program took."),
    ("c", ["try:", "    age = int(input(\"Age? \"))", "except ValueError:", "    print(\"Please type a number.\")"]),
    ("h", "11. Files and persistence"),
    ("b", "Programs remember nothing after they exit unless you save it. Files and databases are how a program keeps its work between runs."),
    ("h", "12. Where to practise"),
    ("b", "Use the Practice tab after every session while the lesson is still fresh. Short, regular practice beats one long session."),
]

EXERCISES = [
    ("t", "Practice Exercises with Solutions"),
    (
        "i",
        "Ten short exercises that match the course. Try each one before reading "
        "its solution, and type the code rather than copying it.",
    ),
    ("h", "Exercise 1 - Hello, World!"),
    ("b", "Print exactly: Hello, World!"),
    ("c", ['print("Hello, World!")']),
    ("h", "Exercise 2 - Variables and names"),
    ("b", "Store your name in a variable, then print a greeting that uses it."),
    ("c", ["name = \"Ada\"", "print(f\"Hello, {name}! Welcome.\")"]),
    ("h", "Exercise 3 - Arithmetic"),
    ("b", "Print the sum and the product of 7 and 6."),
    ("c", ["a = 7", "b = 6", "print(a + b)", "print(a * b)"]),
    ("h", "Exercise 4 - Check your setup"),
    ("b", "Print the version of Python you are running."),
    ("c", ["import sys", "print(sys.version)"]),
    ("h", "Exercise 5 - Types of data"),
    ("b", "Print the type of each of 12, 3.5, \"12\" and True."),
    ("c", ["for value in (12, 3.5, \"12\", True):", "    print(value, type(value))"]),
    ("h", "Exercise 6 - Storing data"),
    ("b", "Ask for two numbers and print their average."),
    ("c", ["first = float(input(\"First number? \"))", "second = float(input(\"Second number? \"))", "print((first + second) / 2)"]),
    ("h", "Exercise 7 - Fix the bug: the endless loop"),
    ("b", "This loop never stops. Work out why, then fix it."),
    ("c", ["# Broken", "count = 3", "while count > 0:", "    print(count)", "", "# Fixed: the value the condition tests must change", "while count > 0:", "    print(count)", "    count = count - 1"]),
    ("h", "Exercise 8 - Fix the bug: the total is text"),
    ("b", "Why does this fail, and how do you fix it?"),
    ("c", ["# Broken: \"Total: \" + 5 mixes text and a number", "print(\"Total: \" + 5)", "", "# Fixed", "print(\"Total: \" + str(5))", "print(f\"Total: {5}\")"]),
    ("h", "Exercise 9 - Loops and lists"),
    ("b", "Print only the even numbers from 1 to 20."),
    ("c", ["for number in range(1, 21):", "    if number % 2 == 0:", "        print(number)"]),
    ("h", "Exercise 10 - A small function"),
    ("b", "Write a function that returns the largest of three numbers, then print the result."),
    ("c", ["def largest(a, b, c):", "    return max(a, b, c)", "", "print(largest(4, 19, 7))"]),
    ("h", "What to do next"),
    ("b", "Open the Practice tab in the app and complete the tasks in order. Each one checks your output for you, so you get feedback straight away."),
]

CAREER_GUIDE = [
    ("t", "Career Guide - Tech in Ghana"),
    (
        "i",
        "How to turn the Python you are learning into work, with practical notes "
        "on your CV, interviews and where the openings are.",
    ),
    ("h", "Start from what you can do"),
    ("b", "Employers in Ghana hire juniors for demonstrated ability, not certificates alone. Build two or three small projects you can explain and show: a script that automates something tedious, a simple web page backed by data, or a dashboard built from a spreadsheet you cleaned."),
    ("h", "Your CV"),
    ("u", ["One page. Name, contact, a one-line summary, skills, projects, education.", "Lead with projects: what you built, which tools, what it did.", "Name the technologies where they belong - Python, Git, SQL, Excel.", "Say what you did, not what you were responsible for: \"wrote a script that cut data entry from 3 hours to 10 minutes\".", "Keep it a PDF and check it opens on a phone; many recruiters read it there first."]),
    ("h", "Sample project line"),
    ("b", "\"Attendance tracker (Python, SQLite) - reads a CSV of daily sign-ins, flags learners who missed three sessions, and prints a weekly summary. Reduced manual reporting to one command.\""),
    ("h", "Where the openings are"),
    ("u", ["Software and product teams in Accra and Kumasi, including fintech and mobile money", "Data and reporting roles in banks, telcos, insurers and NGOs", "Freelance and remote work through Upwork, Toptal and Ghanaian tech communities", "Support, QA and automation roles that often convert into engineering", "Teaching and training - the demand for Python tutors is steady"]),
    ("h", "Preparing for an interview"),
    ("u", ["Expect to write a little code, and to explain it out loud.", "Practise talking through your own project without notes.", "Be ready for the basics: types, loops, functions, and how you debug.", "Ask what the team builds and what a normal week looks like.", "Bring questions; it shows you are choosing them too."]),
    ("h", "Common interview questions"),
    ("b", "What is the difference between a list and a dict? Walk me through your last project. How do you find a bug in code you did not write? Why do you want to work here? Tell me about a time you were stuck and what you did about it."),
    ("h", "Building a network"),
    ("u", ["Attend local meetups and developer events, and introduce yourself to one new person each time.", "Publish your projects - a public repository is a live CV.", "Contribute to open source, even documentation.", "Keep an account of what you are learning; it is a story you can tell."]),
    ("h", "Beyond the first job"),
    ("b", "The skills compound. Reading other people's code, writing tests, and using version control properly are what separate someone who can write a script from someone who can be trusted with a product. Keep practising the fundamentals and the rest follows."),
]

DOCS = [
    ("python_basics_cheat_sheet.pdf", CHEAT_SHEET),
    ("course_slides_demystifying_python.pdf", SLIDES),
    ("practice_exercises.pdf", EXERCISES),
    ("career_guide_tech_in_ghana.pdf", CAREER_GUIDE),
]


def build(name, blocks):
    head = blocks[0]
    pdf = Handout(head[1])
    pdf.add_page()
    for block in blocks[1:]:
        kind = block[0]
        if kind == "i":
            intro(pdf, block[1])
        elif kind == "h":
            heading(pdf, block[1])
        elif kind == "b":
            body(pdf, block[1])
        elif kind == "u":
            bullets(pdf, block[1])
        elif kind == "c":
            code(pdf, block[1])
    path = os.path.join(OUT, name)
    pdf.output(path)
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, blocks in DOCS:
        path = build(name, blocks)
        print(f"wrote {os.path.relpath(path, ROOT)} ({os.path.getsize(path)} bytes)")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        OUT = sys.argv[1]
    main()
