package js.form.field.upload;

import js.form.field.Field.FieldProps;
import js.html.Event;
import js.lib.TestUpload;
import js.ui.Drag;

@:allow(js.form.field.upload.UploadFieldApiAccess)
class UploadField extends Field {
  static public var REG = 'upload';

  public var fileBaseUrl(default, null): String;
  var onUpload: Null<OnUploadProps>;
  var onUploadAddForm: Null<FormListField>;
  var onUploadToFieldId: Null<String>;
  var onUploadFormAdded: Null<Form>;
  public var showType(default, null): Bool;

  // Таймаут хранения файла во временном хранилище файлового сервера
  var tempTimeout: Int;
  var tempTimer: Int;

  var newContainerTags: Array<Tag>;
  var editContainerTags: Array<Tag>;
  var progressContainerTag: Null<Tag>;

  var api: UploadFieldApi;
  var apiAccess: UploadFieldApiAccess;
  var progress: Null<UploadFieldProgress>;
  var preview: Null<UploadFieldPreview>;
  var drag: Drag;

  var val: Dynamic;

  public function new(form: Form, props: UploadFieldProps) {
    super(form, props);
    var uc: UploadConfig = G.require(form.config.uploadConfig, "UploadConfig is not configured");

    apiAccess = new UploadFieldApiAccess(this);

    apiAccess.uploadServer = props.uploadServer[G.location.protocol == 'https:' ? 1 : 0];
    fileBaseUrl = props.fileBaseUrl;
    onUpload = props.onUpload;
    if (onUpload != null) {
      onUploadAddForm = G.require(cast form.fields.get(onUpload.addForm), 'OnUpload addForm "' + onUpload.addForm + '" not found');
      onUploadAddForm.listen(FormListField.AddRemoveEvent, function() {showHideMany(newContainerTags, onUploadAddForm.canAddForm());});
      onUploadToFieldId = onUpload.toField;
    }
    showType = props.showType;
    tempTimeout = initTempTimeout(uc);
    api = G.require(initApi(uc), "No UploadFieldApi configured");
    progress = initProgress(uc);
    preview = initPreview(uc);

    newContainerTags = showHideMany(findTags(uc.uploadNewCls), false);
    editContainerTags = showHideMany(findTags(uc.uploadEditCls), false);
    progressContainerTag = findTags(uc.uploadProgressCls)[0];
    if (progressContainerTag != null) showHide(progressContainerTag, false);
    apiAccess.uploadFilenameBlockTags = findTags(uc.uploadFilenameCls);

    if (initUploader()) {
      function openFileChooser(e: Event) {
        if (e.target != tag.el) { // Защита от циклических событий click, когда tag лежит в newContainerTag
          tag.trigger('click');
          e.preventDefault();
        }
      }
      for (t in newContainerTags) t.onClick(openFileChooser);
      for (t in findTags(uc.uploadOpenCls)) t.onClick(openFileChooser);
      for (t in findTags(uc.uploadClearCls)) t.onClick(function(e: Event) {setValue(null); e.preventDefault();});

      initProgressContainer();
    }
  }

  function findTags(cls: String): Array<Tag> return form.tag.fndAll('.' + cls + '[data-target=' + htmlId + ']');

  function initTempTimeout(c: UploadConfig): Int return c.tempTimeout;

  function initApi(c: UploadConfig): UploadFieldApi return c.api();

  function initProgress(c: UploadConfig): Null<UploadFieldProgress> return c.uploadFieldProgress();

  function initPreview(c: UploadConfig): Null<UploadFieldPreview> return c.uploadFieldPreview();

  function initUploader(): Bool {
    if (!TestUpload.testUpload()) {
      onOldBrowser();
      return false;
    }

    for (newContainerTag in newContainerTags) {
      drag = new Drag(newContainerTag);
      drag.hoverClass(newContainerTag, form.config.uploadConfig.dragOverCls);
      drag.listen(Drag.DropEvent, function(e: Event) {api.startUpload(apiAccess, untyped e.dataTransfer.files);});
    }

    tag.on('change', function() {api.startUpload(apiAccess, untyped tag.el.files);});
    return true;
  }

  function onOldBrowser() {
    for (t in newContainerTags) t.setHtml(form.config.strings.oldBrowserHtml());
  }

  function showError(error: String) {
    form.config.uploadConfig.showErrorMessage(form.config, error);
    setValue(apiAccess.valueBeforeUpload);
    drag.onCancelDrag();
  }

  function showUnexpectedError() {
    showError(form.config.strings.unexpectedError());
  }

  function initProgressContainer() {
    if (progressContainerTag != null && progress != null) {
      progress.initAndAddTo(progressContainerTag.removeChildren());
    }
  }

  function showProgressContainer() {
    showHideMany(newContainerTags, false);
    showHideMany(editContainerTags, false);
    showHide(progressContainerTag, true);
    if (progress != null) {
      progressValue(0);
      progress.show();
    }
  }

  function progressValue(percent: Float) {
    if (progress != null) progress.progress(percent);
  }

  override public function initBoxTag(): Tag {
    var dropContainer = tag.fndParent(function(t: Tag) return t.hasCls(form.config.uploadConfig.dropContainerCls));
    return dropContainer != null ? dropContainer : super.initBoxTag();
  }

  override public function setValueEl(value: Null<Dynamic>) {
    val = value;
    stopTempTimer();
    if (value != null) {
      if (onUploadAddForm != null) {
        onUploadFormAdded = onUploadAddForm.addForm(true);
        onUploadFormAdded.fields.get(onUploadToFieldId).setValue(value);
        val = null;
      } else {
        if (preview != null) {
          preview.managePreviews(this, findTags, value);
        }
      }
    }

    showHide(progressContainerTag, false);
    showHideMany(newContainerTags, onUploadAddForm != null ? onUploadAddForm.canAddForm() : !value);
    showHideMany(editContainerTags, G.toBool(value));
    tag.setVal(null);
  }

  function stopTempTimer() {
    if (tempTimer != null) {
      G.window.clearTimeout(tempTimer);
      tempTimer = null;
    }
  }

  function startTempTimer() {
    var addedForm: Null<Form> = onUploadAddForm != null ? onUploadFormAdded : null;
    stopTempTimer();
    tempTimer = G.window.setTimeout(function() {
      if (addedForm != null) onUploadAddForm.removeForm(addedForm);
      else setValue(null);
      tempTimer = null;
      form.config.uploadConfig.showErrorMessage(form.config, form.config.strings.unableToUploadFile(apiAccess.uploadedFilename));
    }, tempTimeout);
  }

  override public function value(): Dynamic return val;
}


/*
Interface to access private vars and functions of UploadField class.
Also contains some vars mainly needed by UploadFieldApi.
 */
class UploadFieldApiAccess {

  // ------------------------------- Config -------------------------------

  public var field: UploadField;
  public var uploadServer: String;
  public var uploadFilenameBlockTags: Array<Tag>;

  // ------------------------------- Vars -------------------------------

  public var valueBeforeUpload: Dynamic;
  public var uploadedFilename: String;

  public function new(field: UploadField) {
    this.field = field;
  }

  inline public function showUnexpectedError() {field.showUnexpectedError();}

  inline public function showError(error: String) {field.showError(error);}

  inline public function showProgressContainer(): Void {field.showProgressContainer(); }

  inline public function startTempTimer(): Void {field.startTempTimer(); }

  inline public function progressValue(percent: Float): Void {field.progressValue(percent);}
}


@:build(macros.ExternalFieldsMacro.build())
class UploadFieldProps extends FieldProps {
  public var uploadServer: Array<String>;
  public var fileBaseUrl: String;
  @:optional public var onUpload: OnUploadProps;
  public var showType: Bool;
}

@:build(macros.ExternalFieldsMacro.build())
class OnUploadProps {
  public var addForm: String;
  public var toField: String;
}
