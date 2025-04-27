import WebKit

/// Single source of truth for cookies, local- & sessionStorage, and
/// JavaScript JIT permission across all WKWebViews in this process.
enum SharedWebKit {

    /// One global WKProcessPool => all panes share js/localStorage.
    static let pool: WKProcessPool = WKProcessPool()

    /// Convenience builder for a fully wired configuration.
    static func configuration() -> WKWebViewConfiguration {
        let cfg         = WKWebViewConfiguration()
        cfg.processPool = pool
        cfg.websiteDataStore = .default()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        return cfg
    }

    // --- JavaScript Snippets ---

    /// Gets the current value from the target text area.
    static let getJS: String =
    #"""
    (function() {
        const editor = document.querySelector('#search-input-textarea');
        return editor ? editor.value : null; // Return text or null if not found
    })();
    """#

    // NOTE: The following sendJS is NOT used by the current ChatPane implementation
    // (which generates JS dynamically), but kept here for reference of the
    // argument-passing approach.
    /// Sets the text area's value and simulates Cmd/Ctrl + Enter.
    static let sendJS_UNUSED: String =
    #"""
    (function(promptText) { // Expects promptText as the first argument
        const editor = document.querySelector('#search-input-textarea');
        if (!editor) {
            console.error("PromptSenderApp: Could not find editor #search-input-textarea");
            return 'NO_EDITOR';
        }
        if (typeof promptText !== 'string') {
             console.error("PromptSenderApp: Invalid or missing promptText argument.");
             return 'INVALID_ARG';
        }

        editor.value = promptText;
        const inputEvent = new Event('input', { bubbles: true, cancelable: true });
        editor.dispatchEvent(inputEvent);
        editor.focus();

        setTimeout(() => {
             ['metaKey','ctrlKey'].forEach(mod => {
                const keyDownEvent = new KeyboardEvent('keydown', {
                    key: 'Enter', code: 'Enter', keyCode: 13, which: 13,
                    bubbles: true, cancelable: true, composed: true,
                    [mod]: true
                });
                console.log(`PromptSenderApp: Dispatching keydown with ${mod}=true after setting text`);
                editor.dispatchEvent(keyDownEvent);
            });
            // Optional keyup
            const keyUpEvent = new KeyboardEvent('keyup', {
                 key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true, composed: true
            });
            console.log("PromptSenderApp: Dispatching keyup");
            editor.dispatchEvent(keyUpEvent);

        }, 100);

        return 'OK';
    })();
    """#
}
