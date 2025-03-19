# The Cyber Expertise Diversity Survey - Report

This repository contains the report and analysis components derived from [The Cyber Expertise Diversity Survey](https://warwick.ac.uk/fac/cross_fac/cim/research/research-projects/cyber_expertise_diversity) aimed to inform cyber policy discussions by generating new insights into the value and distribution of cyber expertise and ran from to 12th September 2024 to 30th November 2024.

You are free to reuse this dataset under the Licence conditions. If you use this dataset in your work, please cite it as below:

-   [ ] TODO: incorporate citation file and cite text here ([see #1](https://github.com/WarwickCIM/cyberexpertisediversity_survey/issues/2)).

## About us

The Cyber Expertise Diversity Survey is a project run by the [Centre for Interdisciplinary Methodologies](https://warwick.ac.uk/cim) and the [Research Institute for Sociotechnical Cyber Security (RISCS)](), led by Matt Spencer, RISCS Senior Fellow and Associate Professor at CIM.

Other CIM staff involved in putting the survey together and analysing the data include Carlos Cámara-Menoyo and Timothy Monteath.

The survey aims to inform cyber policy discussions by generating new insights into the value and distribution of cyber expertise.

## Project's structure

This repo uses quarto to create the online and pdf version of the report. Some important files and folders to note are:

-   `_quarto.yml`: this file defines the book's properties, metadata and structure.

-   `content/` this folder contains the files with the actual content of the book

-   `data/` folder containing all the datasets used to generate the analyses and and visualisations

-   `media/` folder containing images, videos... that we want to use in the book.

-   `scripts/` folder containing R scripts needed for the book.

-   `R/` folder containing functions that are needed in the project.

-   `_book/` this folder contains the html and pdf versions of the rendered book. It is not tracked in the git repository to avoid conflicts and because it should be possible to recreate it from scratch based on the other files and folders.

## How to recreate the book

The workflow to recreate the book is as follows:

1.  Edit the `qmd` files in the `content/` folder.
2.  Click on render
3.  It will generate a the book structure in the `_book/` folder.
    1.  If it just generate a standalone file within the content folder, delete the html file and, on RStudio's terminal (next to the console), run the following command `quarto render` .

### Further reading

-   <https://quarto.org/docs/books/>

-   <https://quarto.org/docs/authoring/markdown-basics.html> (and sibling pages)

## Managing dependencies

This project uses [{renv}](https://rstudio.github.io/renv/index.html) to manage dependencies. Quarto detects the presence of `renv/` folder and will install the required dependencies.

To install all packages needed to run the project, on the R terminal run:

```         
renv::restore()
```

This will load all packages and versions stored in the file `renv.lock` and install them.

If you need to install extra packages or need to update the library version, you need to update the `renv.lock` as follows:

1.  Install packages normally (\`install.packages(...)\`
2.  Create a new snapshot of the dependencies and record it into `renv.lock` by running `renv::snapshot()`
3.  From git, create a commit including `renv.lock` and push it to the repository

## Running this for the first time

1.  Clone this repository
2.  Install all dependencies needed: `renv::restore()`
3.  Recreate the book by either:
    1.  opening `index.qmd` (or any other `.qmd` file within `content/`) and click on RStudio's "Render" icon
    2.  running `quarto render` on the Terminal (not the R Console) - This will generate the rendered files in \_book/ . You can now open index.html and navigate them in your web browser.
    3.  running `quarto preview` on the Terminal (not the R Console) - This will run a local server rendering the book in your browser every time a file from the ToC is saved.
4.  Pull changes (pull frequently, specially if others are working in this since the last pull, or you suspect they might)
5.  Make changes to files.
6.  Render the book to preview changes
7.  Create a commit.
8.  Push changes to the repo
