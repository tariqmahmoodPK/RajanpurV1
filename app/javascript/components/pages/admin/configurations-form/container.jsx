import React, { useRef, useEffect } from "react";
import PropTypes from "prop-types";
import { useDispatch, useSelector } from "react-redux";
import { useParams } from "react-router-dom";
import DeleteIcon from "@material-ui/icons/Delete";
import CheckIcon from "@material-ui/icons/Check";
import PublishIcon from "@material-ui/icons/Publish";
import { Typography } from "@material-ui/core";
import { makeStyles } from "@material-ui/core/styles";

import { useI18n } from "../../../i18n";
import Form, { FormAction, whichFormMode } from "../../../form";
import { PageHeading, PageContent } from "../../../page";
import LoadingIndicator from "../../../loading-indicator";
import NAMESPACE from "../user-groups-list/namespace";
import { SAVE_METHODS } from "../../../../config";
import bindFormSubmit from "../../../../libs/submit-form";
import ActionDialog, { useDialog } from "../../../action-dialog";
import { enqueueSnackbar } from "../../../notifier";
import { useApp } from "../../../application";

import { form, validations } from "./form";
import {
  applyConfiguration,
  clearSelectedConfiguration,
  deleteConfiguration,
  fetchConfiguration,
  saveConfiguration,
  sentToProduction
} from "./action-creators";
import { getConfiguration, getErrors, getServerErrors, getApplying, getSending } from "./selectors";
import { NAME, APPLY_CONFIGURATION_MODAL, DELETE_CONFIGURATION_MODAL, SEND_CONFIGURATION_MODAL } from "./constants";
import { buildErrorMessages } from "./utils";
import styles from "./styles.css";

const Container = ({ mode }) => {
  const formMode = whichFormMode(mode);
  const i18n = useI18n();
  const formRef = useRef();
  const dispatch = useDispatch();
  const { id } = useParams();
  const { demo: isDemoSite } = useApp();
  const css = makeStyles(styles)();
  const isEditOrShow = formMode.get("isEdit") || formMode.get("isShow");
  const configuration = useSelector(state => getConfiguration(state));
  const errors = useSelector(state => getErrors(state));
  const applying = useSelector(state => getApplying(state));
  const sending = useSelector(state => getSending(state));
  const formErrors = useSelector(state => getServerErrors(state));
  const validationSchema = validations(formMode, i18n);

  const { dialogOpen, dialogClose, pending, setDialogPending, setDialog } = useDialog([
    APPLY_CONFIGURATION_MODAL,
    DELETE_CONFIGURATION_MODAL,
    SEND_CONFIGURATION_MODAL
  ]);

  const setApplyModal = () => {
    setDialog({ dialog: APPLY_CONFIGURATION_MODAL, open: true });
  };

  const setSendModal = () => {
    setDialog({ dialog: SEND_CONFIGURATION_MODAL, open: true });
  };

  const setDeleteModal = () => {
    setDialog({ dialog: DELETE_CONFIGURATION_MODAL, open: true });
  };

  const handleSubmit = data => {
    dispatch(
      saveConfiguration({
        id,
        body: { data },
        saveMethod: formMode.get("isEdit") ? SAVE_METHODS.update : SAVE_METHODS.new,
        message: i18n.t(`configurations.messages.${formMode.get("isEdit") ? "updated" : "created"}`)
      })
    );
  };

  const handleApplyModal = () => dispatch(applyConfiguration({ id, i18n }));
  const handleApply = () => setApplyModal(true);
  const handleSend = () => setSendModal(true);

  const handleSuccessDelete = () => {
    setDialogPending(true);

    dispatch(
      deleteConfiguration({
        id,
        message: i18n.t("configurations.messages.deleted")
      })
    );
  };

  const handleDelete = () => setDeleteModal();

  const handleSendToProd = configId => dispatch(sentToProduction(configId, i18n.t("configurations.messages.sent")));

  useEffect(() => {
    if (isEditOrShow) {
      dispatch(fetchConfiguration(id));
    }

    return () => {
      if (isEditOrShow) {
        dispatch(clearSelectedConfiguration());
      }
    };
  }, [id]);

  useEffect(() => {
    if (errors) {
      const messages = buildErrorMessages(formErrors);

      if (messages !== "") {
        dispatch(enqueueSnackbar(messages, { type: "error" }));
      }
    }
  }, [errors]);

  const pageHeading = configuration?.size ? configuration.get("name") : i18n.t("configurations.label_new");

  const renderSendToProductionBtn = isDemoSite && (
    <FormAction actionHandler={handleSend} text={i18n.t("buttons.send")} startIcon={<PublishIcon />} />
  );

  const editButton = formMode.get("isShow") ? (
    <>
      <FormAction actionHandler={handleDelete} text={i18n.t("buttons.delete")} startIcon={<DeleteIcon />} />
      <FormAction actionHandler={handleApply} text={i18n.t("buttons.apply")} startIcon={<CheckIcon />} />
      {renderSendToProductionBtn}
    </>
  ) : null;

  const saveButton =
    formMode.get("isEdit") || formMode.get("isNew") ? (
      <>
        <FormAction
          actionHandler={() => bindFormSubmit(formRef)}
          text={i18n.t("buttons.save")}
          savingRecord={applying}
          startIcon={<CheckIcon />}
        />
      </>
    ) : null;

  return (
    <LoadingIndicator
      hasData={formMode.get("isNew") || configuration?.size > 0}
      loading={!configuration?.size}
      type={NAMESPACE}
    >
      <PageHeading title={pageHeading}>
        {editButton}
        {saveButton}
      </PageHeading>
      <PageContent>
        <Typography component="h5" color="textSecondary">
          {i18n.t("configurations.explanation")}
        </Typography>
        <br />
        <Form
          useCancelPrompt
          mode={mode}
          formSections={form(i18n, formMode.get("isShow"))}
          onSubmit={handleSubmit}
          ref={formRef}
          validations={validationSchema}
          initialValues={configuration.toJS()}
          formErrors={formErrors}
        />
        <ActionDialog
          open={dialogOpen[DELETE_CONFIGURATION_MODAL]}
          successHandler={handleSuccessDelete}
          cancelHandler={dialogClose}
          dialogTitle={i18n.t("fields.remove")}
          dialogText={i18n.t("configurations.delete_label")}
          confirmButtonLabel={i18n.t("buttons.delete")}
          pending={pending}
          omitCloseAfterSuccess
        />
        <ActionDialog
          open={dialogOpen[APPLY_CONFIGURATION_MODAL]}
          successHandler={handleApplyModal}
          cancelHandler={dialogClose}
          dialogTitle={`${i18n.t("buttons.apply")} ${configuration.get("name")}`}
          confirmButtonLabel={i18n.t("buttons.apply")}
          pending={pending}
          omitCloseAfterSuccess
        >
          <div className={css.applyConfigText}>
            {i18n.t("configurations.apply_label")}
            <b>{i18n.t("configurations.apply_label_bold")}</b>
          </div>
        </ActionDialog>
        <ActionDialog
          open={dialogOpen[SEND_CONFIGURATION_MODAL]}
          successHandler={() => handleSendToProd(id)}
          cancelHandler={dialogClose}
          dialogTitle={i18n.t("configurations.send_header")}
          dialogText={i18n.t("configurations.send_text")}
          confirmButtonLabel={i18n.t("buttons.send")}
          pending={sending}
        />
      </PageContent>
    </LoadingIndicator>
  );
};

Container.displayName = NAME;

Container.propTypes = {
  mode: PropTypes.string.isRequired
};

export default Container;
