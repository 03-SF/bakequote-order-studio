import { Link, createFileRoute } from "@tanstack/react-router";
import { buttonVariants } from "@/components/bq/ui";
import hero from "@/assets/bakery-hero.jpg";
import { Wordmark } from "@/components/bq/shell";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "BakeQuote — Welcome" },
      { name: "description", content: "Choose the customer or baker demo of BakeQuote." },
      { property: "og:title", content: "BakeQuote — Welcome" },
      { property: "og:description", content: "Choose the customer or baker demo of BakeQuote." },
    ],
  }),
  component: Welcome,
});

function Welcome() {
  return (
    <div className="mx-auto max-w-4xl px-4 py-8">
      <Wordmark className="text-2xl" />
      <img
        src={hero}
        alt="Floral cake on a kitchen counter"
        width={1280}
        height={800}
        className="mt-6 w-full rounded-2xl object-cover"
      />
      <h1 className="mt-6 text-3xl font-semibold">Custom cakes, quoted clearly.</h1>
      <p className="mt-2 text-muted-foreground">
        Explore the existing demo orders and conversations. Request creation and live accounts are
        still being built.
      </p>
      <div className="mt-5 flex flex-wrap gap-3">
        <Link
          to="/auth"
          search={{ role: "customer", mode: "signin" }}
          className={buttonVariants({})}
        >
          Explore as customer
        </Link>
        <Link
          to="/auth"
          search={{ role: "baker", mode: "signin" }}
          className={buttonVariants({ variant: "outline" })}
        >
          Explore as baker
        </Link>
      </div>
    </div>
  );
}
