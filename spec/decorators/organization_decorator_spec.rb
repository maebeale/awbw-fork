require "rails_helper"

RSpec.describe OrganizationDecorator do
  describe ".program_status_classes" do
    it "maps each status to its pill classes, accepting symbols or model strings" do
      expect(described_class.program_status_classes(:new)).to include("green")
      expect(described_class.program_status_classes(:ongoing)).to include("blue")
      expect(described_class.program_status_classes(:reinstated)).to include("purple")
      # Organization#program_status returns "Reinstate" (no trailing d).
      expect(described_class.program_status_classes("Reinstate")).to include("purple")
    end

    it "uses purple, not amber, for reinstated" do
      classes = described_class.program_status_classes(:reinstated)
      expect(classes).to include("purple")
      expect(classes).not_to include("amber")
    end

    it "is nil for a blank or unknown status" do
      expect(described_class.program_status_classes(nil)).to be_nil
      expect(described_class.program_status_classes(:bogus)).to be_nil
    end
  end

  describe "#program_status_badge" do
    let(:organization) { create(:organization) }

    it "renders a single-letter badge with the full label as a tooltip" do
      badge = Capybara.string(organization.decorate.program_status_badge(:ongoing))
      expect(badge).to have_css("span[title='Ongoing']", text: "O")
    end

    it "defaults to the organization's own program status" do
      create(:affiliation, organization: organization, person: create(:person), title: "Facilitator")

      badge = Capybara.string(organization.reload.decorate.program_status_badge)
      expect(badge).to have_css("span[title='Ongoing']", text: "O")
    end

    it "is nil for a blank status" do
      expect(organization.decorate.program_status_badge(nil)).to be_nil
    end
  end

  describe "#facilitator_status_as_of" do
    let(:organization) { create(:organization) }
    let(:person) { create(:person) }
    let(:reference) { Date.new(2026, 6, 1) }

    it "is :new when there are no facilitator affiliations starting before the date" do
      expect(organization.decorate.facilitator_status_as_of(reference)).to eq(:new)
    end

    it "ignores facilitator affiliations that start on or after the date" do
      create(:affiliation, organization: organization, person: person, title: "Facilitator", start_date: reference)
      expect(organization.reload.decorate.facilitator_status_as_of(reference)).to eq(:new)
    end

    it "is :ongoing when an earlier facilitator affiliation is still active on the date" do
      create(:affiliation, organization: organization, person: person, title: "Facilitator", start_date: reference - 1.year, end_date: nil)
      expect(organization.reload.decorate.facilitator_status_as_of(reference)).to eq(:ongoing)
    end

    it "is :reinstated when earlier facilitator affiliations all ended before the date" do
      create(:affiliation, organization: organization, person: person, title: "Facilitator", start_date: reference - 2.years, end_date: reference - 1.year)
      expect(organization.reload.decorate.facilitator_status_as_of(reference)).to eq(:reinstated)
    end

    it "ignores non-facilitator affiliations" do
      create(:affiliation, organization: organization, person: person, title: "Volunteer", start_date: reference - 1.year, end_date: nil)
      expect(organization.reload.decorate.facilitator_status_as_of(reference)).to eq(:new)
    end
  end

  describe "#agency_type_option" do
    it "returns a recognized type unchanged" do
      organization = create(:organization, agency_type: "For-profit")
      expect(organization.decorate.agency_type_option).to eq("For-profit")
    end

    it "folds a legacy 'Other' label into the catch-all 'Other'" do
      organization = create(:organization, agency_type: "Other (please specify below)")
      expect(organization.decorate.agency_type_option).to eq("Other")
    end

    it "leaves a blank value blank" do
      organization = create(:organization, agency_type: "")
      expect(organization.decorate.agency_type_option).to eq("")
    end
  end

  describe "#profile_display_summary" do
    it "says everything is shown when no toggle is hidden" do
      expect(create(:organization).decorate.profile_display_summary).to eq("All shown")
    end

    it "names only the hidden items, prefixed with Hide" do
      organization = create(:organization, profile_show_phone: false, profile_show_website: false)
      expect(organization.decorate.profile_display_summary).to eq("Hide phone and website")
    end

    it "uses the checkbox wording for a hidden item" do
      organization = create(:organization, profile_show_events_registered: false)
      expect(organization.decorate.profile_display_summary).to eq("Hide events hosted")
    end
  end

  describe "#background_summary" do
    it "leads with the organization type" do
      org = create(:organization, agency_type: "501c3/nonprofit")
      expect(org.decorate.background_summary).to include("501c3/nonprofit")
    end

    it "shows the specify-text for an 'Other' type" do
      org = create(:organization, agency_type: Organization::AGENCY_TYPE_OTHER, agency_type_other: "Co-op")
      expect(org.decorate.background_summary).to include("Co-op")
    end

    it "adds a pill for each filled optional field and omits blank ones" do
      org = create(:organization, agency_type: "501c3/nonprofit", email: "hi@example.org",
                   description: "About us", website_url: "", mission_vision_values: "")
      summary = org.decorate.background_summary
      expect(summary).to include("Email", "Description")
      expect(summary).not_to include("Website", "Mission/vision/values")
    end
  end

  describe "#sectors_summary" do
    it "is 'None selected' with no sectors" do
      expect(create(:organization).decorate.sectors_summary).to eq("None selected")
    end

    it "bolds and stars the primary, crowns and labels the leader" do
      org = create(:organization)
      health = create(:sector, name: "Health/Medical")
      housing = create(:sector, name: "Housing")
      create(:sectorable_item, sectorable: org, sector: health, is_primary: true, is_leader: true)
      create(:sectorable_item, sectorable: org, sector: housing)

      summary = org.reload.decorate.sectors_summary
      expect(summary).to include("fa-star", "fa-crown", "<strong>Health/Medical</strong>", "(sector leader)")
      expect(summary).to include("Housing")
    end
  end
end
