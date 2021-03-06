package webby.form.field.autocomplete

import webby.form.Form
import webby.form.field.TextField

/**
 * Текстовое поле, аналогичное TextField, но с поддержкой необязательного автокомплита.
 */
class AutocompleteTextField(form: Form,
                            id: String,
                            var jsSourceFunction: String,
                            var jsSourceArg: Any = null) extends TextField(form, id) {self =>

  // ------------------------------- Reading data & js properties -------------------------------
  class AutocompleteJsProps extends JsProps {
    val sourceFn = self.jsSourceFunction
    val sourceArg = self.jsSourceArg
  }
  override def jsProps = new AutocompleteJsProps
  override def jsField: String = "autocompleteText"
}
