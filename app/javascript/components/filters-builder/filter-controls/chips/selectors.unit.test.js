
import chai, { expect } from "chai";
import { Map } from "immutable";
import chaiImmutable from "chai-immutable";
import * as selectors from "./selectors";

chai.use(chaiImmutable);

const stateWithNoRecords = Map({
  records: Map({
    Cases: {
      filters: {
        risk_level: []
      }
    }
  })
});
const stateWithRecords = Map({
  records: Map({
    Cases: {
      filters: {
        risk_level: ["low", "high"]
      }
    }
  })
});

describe("<Chips /> - Selectors", () => {
  describe("getChips", () => {
    it("should return records", () => {
      const expected = ["low", "high"];
      const records = selectors.getChips(
        stateWithRecords,
        { id: "risk_level" },
        "Cases"
      );
      expect(records).to.deep.equal(expected);
    });

    it("should return empty object when records empty", () => {
      const expected = [];
      const records = selectors.getChips(
        stateWithNoRecords,
        { id: "risk_level" },
        "Cases"
      );
      expect(records).to.deep.equal(expected);
    });
  });
});

