require "rails_helper"

RSpec.describe PersonDecorator do
  describe "#active_facilitator_organization_names" do
    let(:person) { create(:person) }

    it "returns sorted, unique org names for active facilitator affiliations" do
      beta = create(:organization, name: "Beta Org")
      alpha = create(:organization, name: "Alpha Org")
      create(:affiliation, person: person, organization: beta, title: "Facilitator")
      create(:affiliation, person: person, organization: alpha, title: "Facilitator")

      expect(person.decorate.active_facilitator_organization_names).to eq([ "Alpha Org", "Beta Org" ])
    end

    it "excludes non-facilitator affiliations" do
      org = create(:organization, name: "Board Org")
      create(:affiliation, person: person, organization: org, title: "Board Member")

      expect(person.decorate.active_facilitator_organization_names).to be_empty
    end

    it "excludes expired facilitator affiliations" do
      org = create(:organization, name: "Past Org")
      create(:affiliation, person: person, organization: org, title: "Facilitator", end_date: 1.day.ago)

      expect(person.decorate.active_facilitator_organization_names).to be_empty
    end
  end

  describe "#affiliated_since_date" do
    let(:person) { create(:person) }

    it "returns the earliest affiliation start date" do
      create(:affiliation, person: person, start_date: Date.new(2024, 5, 1))
      create(:affiliation, person: person, start_date: Date.new(2022, 3, 1))
      create(:affiliation, person: person, start_date: Date.new(2023, 8, 1))

      expect(person.decorate.affiliated_since_date).to eq(Date.new(2022, 3, 1))
    end

    it "ignores affiliations without a start date" do
      create(:affiliation, person: person, start_date: nil)
      create(:affiliation, person: person, start_date: Date.new(2021, 1, 1))

      expect(person.decorate.affiliated_since_date).to eq(Date.new(2021, 1, 1))
    end

    it "is nil when there are no affiliations with a start date" do
      create(:affiliation, person: person, start_date: nil)

      expect(person.decorate.affiliated_since_date).to be_nil
    end
  end

  describe "#profile_display_summary" do
    it "says everything is shown when no toggle is hidden" do
      expect(create(:person).decorate.profile_display_summary).to eq("All shown")
    end

    it "names only the hidden items, prefixed with Hide" do
      person = create(:person, profile_show_phone: false, profile_show_bio: false)
      expect(person.decorate.profile_display_summary).to eq("Hide phone and bio")
    end

    it "uses the checkbox wording for a hidden item" do
      person = create(:person, profile_show_member_since: false)
      expect(person.decorate.profile_display_summary).to eq("Hide facilitator since")
    end
  end

  describe "#sectors_summary" do
    it "is 'None selected' with no sectors" do
      expect(create(:person).decorate.sectors_summary).to eq("None selected")
    end

    it "bolds and stars the primary, crowns and labels the leader" do
      person = create(:person)
      health = create(:sector, name: "Health/Medical")
      create(:sectorable_item, sectorable: person, sector: health, is_primary: true, is_leader: true)

      summary = person.reload.decorate.sectors_summary
      expect(summary).to include("fa-star", "fa-crown", "<strong>Health/Medical</strong>", "(sector leader)")
    end
  end

  describe "#age_ranges_summary" do
    it "is 'None selected' with no age ranges" do
      expect(create(:person).decorate.age_ranges_summary).to eq("None selected")
    end

    it "bolds and stars the primary age range (no crown)" do
      person = create(:person)
      age_type = create(:category_type, :published, name: "AgeRange")
      kids = create(:category, :published, category_type: age_type, name: "Children (0-12)")
      teens = create(:category, :published, category_type: age_type, name: "Teens (13-17)")
      create(:categorizable_item, categorizable: person, category: kids, is_primary: true)
      create(:categorizable_item, categorizable: person, category: teens)

      summary = person.reload.decorate.age_ranges_summary
      expect(summary).to include("fa-star", "<strong>Children (0-12)</strong>", "Teens (13-17)")
      expect(summary).not_to include("fa-crown")
    end
  end
end
