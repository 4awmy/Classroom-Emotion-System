# 🎓 Welcome to the Classroom Emotion System (Shiny Portal)

Hey there! If you're a Computer Science student looking at this codebase, welcome! This guide will help you understand how our web portal is built and why we made certain architectural choices. 

Think of this as the "Owner's Manual" for the R/Shiny part of our project.

---

## 📚 Key Terms to Know

Before we dive into the "How," let's define the "What":

| Term | Analogy | Definition |
| :--- | :--- | :--- |
| **UI (User Interface)** | The Face | Everything the user sees: buttons, sliders, and charts. Defined in R but rendered as HTML/CSS in the browser. |
| **Server** | The Brain | The logic center. It listens for user input, processes data, and sends instructions back to the UI. |
| **Reactive** | The Domino Effect | A special type of variable. When a reactive variable changes, everything that depends on it automatically "reacts" and updates. |
| **Global** | The Foundation | Code that runs once when the app starts. It loads libraries and sets up data that everyone needs. |
| **Module** | Lego Blocks | A self-contained piece of UI and Server logic that can be reused multiple times without getting messy. |

---

## 🏗️ Architecture Deep Dive

### 1. The "Moodle Costume" (`htmlTemplate`)
**Concept:** Theming & Encapsulation

Ever notice how our app looks exactly like the university's Moodle page? We achieve this using `htmlTemplate`. 

Instead of letting Shiny generate a generic-looking page, we provide it with a raw HTML file (the "costume"). Shiny then "injects" its interactive components into specific slots in that HTML.
*   **Why?** It provides a seamless experience for lecturers who are already used to the Moodle interface.
*   **Benefit:** It separates the **design** (HTML/CSS) from the **logic** (R code).

### 2. The "Nightly Newspaper" (`reactivePoll`)
**Concept:** Polling vs. Push

Our app doesn't talk to the live database every second. Instead, it uses `reactivePoll`.

Imagine you want to know the news. You could stand at the window and watch the street all day (Push), or you could just check your front porch every morning for the newspaper (Polling). 
*   **How it works:** Every 60 seconds, Shiny checks the "last modified" timestamp of our data files. If the timestamp hasn't changed, Shiny does nothing. If it *has* changed (like after the nightly 2:00 AM export), Shiny reloads the data.
*   **Why?** It saves resources and prevents the app from slowing down by constantly asking for data that hasn't changed yet.

### 3. The "Firewall" (Data Isolation)
**Concept:** Separation of Concerns

One of our strictest rules is: **The Shiny app never touches the SQLite database.**

*   **The Backend (FastAPI)** is the only one allowed to write to the database.
*   **The Web Portal (Shiny)** only reads static CSV files exported by the backend.
*   **Why?** This is a safety measure. If a bug in the web portal goes haywire, it physically *cannot* corrupt the live student data because it doesn't have the "keys" to the database.

### 4. Lego Blocks (Modularity)
**Concept:** Modularity

As the app grows, putting thousands of lines of code into one `app.R` file becomes a nightmare. We split the app into multiple files:
*   `global.R`: For setup and loading data.
*   `ui.R`: For the layout.
*   `server.R`: For the logic.
*   `R/modules/`: For specific features like "Attendance Chart" or "Emotion Heatmap."

**Why?** It makes the code easier to read, easier to test, and allows multiple developers to work on different parts of the app at the same time without stepping on each other's toes.

---

## 🚀 Summary
We built this app to be **safe** (Data Isolation), **efficient** (Reactive Polling), **familiar** (HTML Templates), and **organized** (Modularity). 

Happy coding! If you have questions, check out the `ARCHITECTURE.md` in the root folder for the full technical specs.
