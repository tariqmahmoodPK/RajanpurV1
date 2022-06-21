import * as constants from "./constants";

describe("<InsightsSubReport /> - constants", () => {
  const clone = { ...constants };

  it("should have known properties", () => {
    expect(clone).to.be.an("object");
    [
      "COMBINED_INDICATORS",
      "GROUPED_BY_FILTER",
      "NAME",
      "REPORTING_LOCATION_INSIGHTS",
      "INSIGHTS_WITH_SUBCOLUMNS_ITEMS"
    ].forEach(property => {
      expect(clone).to.have.property(property);
      delete clone[property];
    });

    expect(clone).to.be.empty;
  });
});
