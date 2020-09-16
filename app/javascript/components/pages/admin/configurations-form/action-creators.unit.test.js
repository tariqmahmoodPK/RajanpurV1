import { stub } from "../../../../test";
import { RECORD_PATH, METHODS, SAVE_METHODS, ROUTES } from "../../../../config";
import { ENQUEUE_SNACKBAR, generate, SNACKBAR_VARIANTS } from "../../../notifier";

import * as actionsCreators from "./action-creators";
import actions from "./actions";

describe("configurations-form/action-creators.js", () => {
  describe("exported action-creators", () => {
    let clone;

    before(() => {
      clone = { ...actionsCreators };
    });

    after(() => {
      expect(clone).to.be.empty;
    });

    [
      "applyConfiguration",
      "checkConfiguration",
      "clearSelectedConfiguration",
      "deleteConfiguration",
      "fetchConfiguration",
      "getApplyingConfigMessage",
      "saveConfiguration"
    ].forEach(actionCreator => {
      it(`exports '${actionCreator}'`, () => {
        expect(clone).to.have.property(actionCreator);
        delete clone[actionCreator];
      });
    });
  });

  describe("exported objects by action-creators", () => {
    it("should check that 'applyConfiguration' action creator returns the correct object", () => {
      const args = { id: 1, message: "Test success message" };
      const expected = {
        type: actions.APPLY_CONFIGURATION,
        api: {
          path: `${RECORD_PATH.configurations}/${args.id}`,
          method: METHODS.PATCH,
          body: {
            data: {
              apply_now: true
            }
          },
          configurationCallback: {
            type: actions.CHECK_CONFIGURATION,
            api: {
              external: true,
              path: ROUTES.check_health
            }
          }
        }
      };

      expect(actionsCreators.applyConfiguration(args)).to.deep.equal(expected);
    });

    it("should check that 'checkConfiguration' action creator returns the correct object", () => {
      const expected = {
        type: actions.CHECK_CONFIGURATION,
        api: {
          external: true,
          path: ROUTES.check_health
        }
      };

      expect(actionsCreators.checkConfiguration(1234)).to.deep.equal(expected);
    });

    it("should check that 'clearSelectedConfiguration' action creator returns the correct object", () => {
      const expected = {
        type: actions.CLEAR_SELECTED_CONFIGURATION
      };

      expect(actionsCreators.clearSelectedConfiguration()).to.deep.equal(expected);
    });

    it("should check that 'deleteConfiguration' action creator returns the correct object", () => {
      stub(generate, "messageKey").returns(4);

      const args = {
        id: 1,
        message: "Deleted successfully"
      };

      const expected = {
        type: actions.DELETE_CONFIGURATION,
        api: {
          path: `${RECORD_PATH.configurations}/${args.id}`,
          method: METHODS.DELETE,
          successCallback: {
            action: ENQUEUE_SNACKBAR,
            payload: {
              message: args.message,
              options: {
                key: 4,
                variant: "success"
              }
            },
            redirectWithIdFromResponse: false,
            redirect: `/admin/${RECORD_PATH.configurations}`
          }
        }
      };

      expect(actionsCreators.deleteConfiguration(args)).to.deep.equal(expected);
    });

    it("should check that 'fetchConfiguration' action creator returns the correct object", () => {
      const expected = {
        type: actions.FETCH_CONFIGURATION,
        api: {
          path: `${RECORD_PATH.configurations}/1234`
        }
      };

      expect(actionsCreators.fetchConfiguration(1234)).to.deep.equal(expected);
    });

    it("should check that 'getApplyingConfigMessage' action creator returns the correct object", () => {
      const expected = {
        action: ENQUEUE_SNACKBAR,
        payload: {
          message: "Server is temporarily unavailable. Applying new configuration.",
          noDismiss: true,
          options: {
            variant: SNACKBAR_VARIANTS.info,
            key: generate.messageKey(99999)
          }
        }
      };

      expect(actionsCreators.getApplyingConfigMessage()).to.deep.equal(expected);
    });

    it("should check that 'saveConfiguration' action creator returns the correct object", () => {
      stub(generate, "messageKey").returns(4);

      const args = {
        id: 1,
        body: {
          data: {
            name: "TEST - 20200903",
            description: "September 2020 baseline"
          }
        },
        saveMethod: SAVE_METHODS.new,
        message: "Saved successfully"
      };

      const expected = {
        type: actions.SAVE_CONFIGURATION,
        api: {
          path: RECORD_PATH.configurations,
          method: METHODS.POST,
          body: args.body,
          successCallback: {
            action: ENQUEUE_SNACKBAR,
            payload: {
              message: args.message,
              options: {
                key: 4,
                variant: "success"
              }
            },
            redirectWithIdFromResponse: true,
            redirect: `/admin/${RECORD_PATH.configurations}`
          }
        }
      };

      expect(actionsCreators.saveConfiguration(args)).to.deep.equal(expected);
    });
  });

  afterEach(() => {
    if (generate.messageKey.restore) {
      generate.messageKey.restore();
    }
  });
});
