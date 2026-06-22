const STORAGE_KEY = "mass-transcriptor-theme";

function getStoredTheme() {
  const stored = window.localStorage.getItem(STORAGE_KEY);
  return stored === "light" ? "light" : "dark";
}

function applyTheme(theme) {
  document.documentElement.dataset.theme = theme;
  window.localStorage.setItem(STORAGE_KEY, theme);

  document.querySelectorAll("[phx-hook=Theme]").forEach((button) => {
    const isLight = theme === "light";
    const darkIcon = button.querySelector('[data-theme-icon="dark"]');
    const lightIcon = button.querySelector('[data-theme-icon="light"]');
    const label = button.querySelector("[data-theme-label]");

    if (darkIcon) darkIcon.hidden = isLight;
    if (lightIcon) lightIcon.hidden = !isLight;

    if (label) {
      label.textContent = isLight ? button.dataset.themeDarkLabel : button.dataset.themeLightLabel;
    }

    button.setAttribute(
      "aria-label",
      isLight ? button.dataset.themeSwitchToDark : button.dataset.themeSwitchToLight
    );
  });
}

applyTheme(getStoredTheme());

const ThemeHook = {
  mounted() {
    this.el.addEventListener("click", () => {
      const nextTheme = getStoredTheme() === "light" ? "dark" : "light";
      applyTheme(nextTheme);
    });
  },
};

export default ThemeHook;
